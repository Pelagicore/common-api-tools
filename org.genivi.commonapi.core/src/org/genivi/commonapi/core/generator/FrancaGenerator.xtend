/* Copyright (C) 2013 BMW Group
 * Author: Manfred Bathelt (manfred.bathelt@bmw.de)
 * Author: Juergen Gehring (juergen.gehring@bmw.de)
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */
package org.genivi.commonapi.core.generator

import java.util.Collection
import java.util.HashSet
import java.util.LinkedList
import java.util.List
import javax.inject.Inject
import org.eclipse.core.resources.IResource
import org.eclipse.core.resources.ResourcesPlugin
import org.eclipse.core.runtime.Path
import org.eclipse.core.runtime.QualifiedName
import org.eclipse.core.runtime.preferences.DefaultScope
import org.eclipse.core.runtime.preferences.IEclipsePreferences
import org.eclipse.core.runtime.preferences.InstanceScope
import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.xtext.builder.EclipseResourceFileSystemAccess2
import org.eclipse.xtext.generator.IFileSystemAccess
import org.eclipse.xtext.generator.IGenerator
import org.eclipse.xtext.generator.JavaIoFileSystemAccess
import org.franca.core.franca.FArrayType
import org.franca.core.franca.FEnumerationType
import org.franca.core.franca.FInterface
import org.franca.core.franca.FMapType
import org.franca.core.franca.FModel
import org.franca.core.franca.FStructType
import org.franca.core.franca.FType
import org.franca.core.franca.FTypeCollection
import org.franca.core.franca.FTypeDef
import org.franca.core.franca.FTypeRef
import org.franca.core.franca.FUnionType
import org.franca.deploymodel.core.FDModelExtender
import org.franca.deploymodel.core.FDeployedInterface
import org.franca.deploymodel.dsl.FDeployPersistenceManager
import org.franca.deploymodel.dsl.fDeploy.FDInterface
import org.genivi.commonapi.core.deployment.DeploymentInterfacePropertyAccessor
import org.genivi.commonapi.core.deployment.DeploymentInterfacePropertyAccessorWrapper
import org.genivi.commonapi.core.preferences.FPreferences
import org.genivi.commonapi.core.preferences.PreferenceConstants
import org.osgi.framework.FrameworkUtil

import static com.google.common.base.Preconditions.*

class FrancaGenerator implements IGenerator
{
    @Inject private extension FTypeCollectionGenerator
    @Inject private extension FInterfaceGenerator
    @Inject private extension FInterfaceProxyGenerator
    @Inject private extension FInterfaceStubGenerator
    @Inject private extension FInterfaceServiceAbstractGenerator
    @Inject private extension FrancaGeneratorExtensions

    @Inject private MyFrancaPersistenceManager francaPersistenceManager
    @Inject private FDeployPersistenceManager fDeployPersistenceManager

    override doGenerate(Resource input, IFileSystemAccess fileSystemAccess)
    {
        var FModel fModel
        var List<FDInterface> deployedInterfaces
        var IResource res = null

        if(input.URI.fileExtension.equals(francaPersistenceManager.fileExtension))
        {
            fModel = francaPersistenceManager.loadModel(input.filePath)
            deployedInterfaces = new LinkedList<FDInterface>()

        }
        else if(input.URI.fileExtension.equals("fdepl"/* fDeployPersistenceManager.fileExtension */))
        {
            var fDeployedModel = fDeployPersistenceManager.loadModel(input.URI, input.URI);
            val fModelExtender = new FDModelExtender(fDeployedModel);

            checkArgument(fModelExtender.getFDInterfaces().size > 0, "No Interfaces were deployed, nothing to generate.")
            fModel = fModelExtender.getFDInterfaces().get(0).target.model
            deployedInterfaces = fModelExtender.getFDInterfaces()

        }
        else
        {
            checkArgument(false, "Unknown input: " + input)
        }

        try
        {
            var pathfile = input.URI.toPlatformString(false);
            if(pathfile == null)
            {
                pathfile = FPreferences::instance.getModelPath(fModel)
            }
            if(pathfile.startsWith("platform:/"))
            {
                pathfile = pathfile.substring(pathfile.indexOf("platform") + 10)
                pathfile = pathfile.substring(pathfile.indexOf(System.getProperty("file.separator")))
            }

            res = ResourcesPlugin.workspace.root.findMember(pathfile)
            FPreferences::instance.addPreferences(res)
            if(FPreferences::instance.useModelSpecific(res))
            {
                var output = res.getPersistentProperty(
                    new QualifiedName(PreferenceConstants::PROJECT_PAGEID, PreferenceConstants::P_OUTPUT_PROXIES))
                if(output != null && output.length != 0)
                {
                    if(fileSystemAccess instanceof EclipseResourceFileSystemAccess2)
                    {
                        (fileSystemAccess as EclipseResourceFileSystemAccess2).setOutputPath(output)
                    }
                    else if(fileSystemAccess instanceof JavaIoFileSystemAccess)
                    {
                        (fileSystemAccess as JavaIoFileSystemAccess).setOutputPath(output)
                    }
                }
            }
            doGenerateComponents(fModel, deployedInterfaces, fileSystemAccess, res)
        }
        catch(IllegalStateException e)
        {
            //happens only when the cli calls the francagenerator
        }
        doGenerateComponents(fModel, deployedInterfaces, fileSystemAccess, res)

        if(res != null)
        {
            fileSystemAccess.setFileAccessOutputPathForPreference(PreferenceConstants::P_OUTPUT_PROXIES, res)
        }
    }

    def doGenerateComponents(FModel fModel, List<FDInterface> deployedInterfaces, IFileSystemAccess fileSystemAccess, IResource res)
    {

        val allReferencedFTypes = fModel.allReferencedFTypes
        val allFTypeTypeCollections = allReferencedFTypes.filter[eContainer instanceof FTypeCollection].map[
            eContainer as FTypeCollection]
        val allFTypeFInterfaces = allReferencedFTypes.filter[eContainer instanceof FInterface].map[eContainer as FInterface]

        val generateTypeCollections = fModel.typeCollections.toSet
        generateTypeCollections.addAll(allFTypeTypeCollections)

        val generateInterfaces = fModel.allReferencedFInterfaces.toSet
        generateInterfaces.addAll(allFTypeFInterfaces)

        val defaultDeploymentAccessor = new DeploymentInterfacePropertyAccessorWrapper(null) as DeploymentInterfacePropertyAccessor

        generateTypeCollections.forEach [
            generate(it, fileSystemAccess, defaultDeploymentAccessor, res)
        ]

        generateInterfaces.forEach [
            val currentInterface = it
            var DeploymentInterfacePropertyAccessor deploymentAccessor
            if(deployedInterfaces.exists[it.target == currentInterface])
            {
                deploymentAccessor = new DeploymentInterfacePropertyAccessor(
                    new FDeployedInterface(deployedInterfaces.filter[it.target == currentInterface].last))
            }
            else
            {
                deploymentAccessor = defaultDeploymentAccessor
            }
            generate(it, fileSystemAccess, defaultDeploymentAccessor, res)
        ]

        fModel.interfaces.forEach [
            val currentInterface = it
            var DeploymentInterfacePropertyAccessor deploymentAccessor
            if(deployedInterfaces.exists[it.target == currentInterface])
            {
                deploymentAccessor = new DeploymentInterfacePropertyAccessor(
                    new FDeployedInterface(deployedInterfaces.filter[it.target == currentInterface].last))
            }
            else
            {
                deploymentAccessor = defaultDeploymentAccessor
            }
            val booleanTrue = Boolean.toString(true)
            var IEclipsePreferences node
            var String finalValue = booleanTrue
            if(FrameworkUtil::getBundle(this.getClass()) != null)
            {
                node = DefaultScope::INSTANCE.getNode(PreferenceConstants::SCOPE)
                finalValue = node.get(PreferenceConstants::P_GENERATEPROXY, booleanTrue)

                node = InstanceScope::INSTANCE.getNode(PreferenceConstants::SCOPE)
                finalValue = node.get(PreferenceConstants::P_GENERATEPROXY, finalValue)
            }
            finalValue = FPreferences::instance.getPreference(res, PreferenceConstants::P_GENERATEPROXY, finalValue)
            if(finalValue.equals(booleanTrue))
            {
                fileSystemAccess.setFileAccessOutputPathForPreference(PreferenceConstants.P_OUTPUT_PROXIES, res)
                it.generateProxy(fileSystemAccess, deploymentAccessor, res)
            }
            finalValue = booleanTrue
            if(FrameworkUtil::getBundle(this.getClass()) != null)
            {
                node = DefaultScope::INSTANCE.getNode(PreferenceConstants::SCOPE)
                finalValue = node.get(PreferenceConstants::P_GENERATESTUB, booleanTrue)
                node = InstanceScope::INSTANCE.getNode(PreferenceConstants::SCOPE)
                finalValue = node.get(PreferenceConstants::P_GENERATESTUB, finalValue)
            }
            finalValue = FPreferences::instance.getPreference(res, PreferenceConstants::P_GENERATESTUB, finalValue)
            if(finalValue.equals(booleanTrue))
            {
                fileSystemAccess.setFileAccessOutputPathForPreference(PreferenceConstants.P_OUTPUT_STUBS, res)
                it.generateStub(fileSystemAccess, res)
                it.generateServiceAbstract(fileSystemAccess, res)
            }
        ]

        return;
    }

    private var String filePrefix = "file://"

    def getFilePathUrl(Resource resource)
    {
        val filePath = resource.filePath
        return filePrefix + filePath
    }

    def private getFilePath(Resource resource)
    {
        if(resource.URI.file)
        {
            return resource.URI.toFileString
        }

        val platformPath = new Path(resource.URI.toPlatformString(true))
        val file = ResourcesPlugin::getWorkspace().getRoot().getFile(platformPath);

        return file.location.toString
    }

    def private getAllReferencedFInterfaces(FModel fModel)
    {
        val referencedFInterfaces = fModel.interfaces.toSet
        fModel.interfaces.forEach[base?.addFInterfaceTree(referencedFInterfaces)]
        fModel.interfaces.forEach[managedInterfaces.forEach[addFInterfaceTree(referencedFInterfaces)]]
        return referencedFInterfaces
    }

    def private void addFInterfaceTree(FInterface fInterface, Collection<FInterface> fInterfaceReferences)
    {
        if(!fInterfaceReferences.contains(fInterface))
        {
            fInterfaceReferences.add(fInterface)
            fInterface.base?.addFInterfaceTree(fInterfaceReferences)
        }
    }

    def getAllReferencedFTypes(FModel fModel)
    {
        val referencedFTypes = new HashSet<FType>

        fModel.typeCollections.forEach[types.forEach[addFTypeDerivedTree(referencedFTypes)]]

        fModel.interfaces.forEach [
            attributes.forEach[type.addDerivedFTypeTree(referencedFTypes)]
            types.forEach[addFTypeDerivedTree(referencedFTypes)]
            methods.forEach [
                inArgs.forEach[type.addDerivedFTypeTree(referencedFTypes)]
                outArgs.forEach[type.addDerivedFTypeTree(referencedFTypes)]
            ]
            broadcasts.forEach [
                outArgs.forEach[type.addDerivedFTypeTree(referencedFTypes)]
            ]
        ]

        return referencedFTypes
    }

    def private void addDerivedFTypeTree(FTypeRef fTypeRef, Collection<FType> fTypeReferences)
    {
        fTypeRef.derived?.addFTypeDerivedTree(fTypeReferences)
    }

    def private dispatch void addFTypeDerivedTree(FTypeDef fTypeDef, Collection<FType> fTypeReferences)
    {
        if(!fTypeReferences.contains(fTypeDef))
        {
            fTypeReferences.add(fTypeDef)
            fTypeDef.actualType.addDerivedFTypeTree(fTypeReferences)
        }
    }

    def private dispatch void addFTypeDerivedTree(FArrayType fArrayType, Collection<FType> fTypeReferences)
    {
        if(!fTypeReferences.contains(fArrayType))
        {
            fTypeReferences.add(fArrayType)
            fArrayType.elementType.addDerivedFTypeTree(fTypeReferences)
        }
    }

    def private dispatch void addFTypeDerivedTree(FMapType fMapType, Collection<FType> fTypeReferences)
    {
        if(!fTypeReferences.contains(fMapType))
        {
            fTypeReferences.add(fMapType)
            fMapType.keyType.addDerivedFTypeTree(fTypeReferences)
            fMapType.valueType.addDerivedFTypeTree(fTypeReferences)
        }
    }

    def private dispatch void addFTypeDerivedTree(FStructType fStructType, Collection<FType> fTypeReferences)
    {
        if(!fTypeReferences.contains(fStructType))
        {
            fTypeReferences.add(fStructType)
            fStructType.base?.addFTypeDerivedTree(fTypeReferences)
            fStructType.elements.forEach[type.addDerivedFTypeTree(fTypeReferences)]
        }
    }

    def private dispatch void addFTypeDerivedTree(FEnumerationType fEnumerationType, Collection<FType> fTypeReferences)
    {
        if(!fTypeReferences.contains(fEnumerationType))
        {
            fTypeReferences.add(fEnumerationType)
            fEnumerationType.base?.addFTypeDerivedTree(fTypeReferences)
        }
    }

    def private dispatch void addFTypeDerivedTree(FUnionType fUnionType, Collection<FType> fTypeReferences)
    {
        if(!fTypeReferences.contains(fUnionType))
        {
            fTypeReferences.add(fUnionType)
            fUnionType.base?.addFTypeDerivedTree(fTypeReferences)
            fUnionType.elements.forEach[type.addDerivedFTypeTree(fTypeReferences)]
        }
    }

    def void setFileAccessOutputPathForPreference(IFileSystemAccess access, String preference, IResource res)
    {
        var defaultValue = DefaultScope::INSTANCE.getNode(PreferenceConstants::SCOPE).get(preference,
            PreferenceConstants::DEFAULT_OUTPUT);
        defaultValue = InstanceScope::INSTANCE.getNode(PreferenceConstants::SCOPE).get(preference, defaultValue)
        defaultValue = FPreferences::instance.getPreference(res, preference, defaultValue)

        switch (access)
        {
            EclipseResourceFileSystemAccess2:
                access.setOutputPath(defaultValue)
            JavaIoFileSystemAccess:
                access.setOutputPath(defaultValue)
        }
    }
}
