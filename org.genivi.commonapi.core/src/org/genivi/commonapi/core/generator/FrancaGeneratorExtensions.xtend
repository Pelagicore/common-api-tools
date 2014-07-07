/* Copyright (C) 2013 BMW Group
 * Author: Manfred Bathelt (manfred.bathelt@bmw.de)
 * Author: Juergen Gehring (juergen.gehring@bmw.de)
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */
package org.genivi.commonapi.core.generator

import com.google.common.base.Charsets
import com.google.common.hash.Hasher
import com.google.common.hash.Hashing
import com.google.common.primitives.Ints
import java.util.Collection
import java.util.List
import org.eclipse.core.resources.IResource
import org.eclipse.core.resources.ResourcesPlugin
import org.eclipse.core.runtime.Path
import org.eclipse.core.runtime.preferences.DefaultScope
import org.eclipse.core.runtime.preferences.InstanceScope
import org.eclipse.emf.common.util.BasicEList
import org.eclipse.emf.common.util.EList
import org.eclipse.emf.ecore.EObject
import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.emf.ecore.util.EcoreUtil
import org.franca.core.franca.FArrayType
import org.franca.core.franca.FAttribute
import org.franca.core.franca.FBasicTypeId
import org.franca.core.franca.FBroadcast
import org.franca.core.franca.FEnumerationType
import org.franca.core.franca.FField
import org.franca.core.franca.FInterface
import org.franca.core.franca.FMapType
import org.franca.core.franca.FMethod
import org.franca.core.franca.FModel
import org.franca.core.franca.FModelElement
import org.franca.core.franca.FStructType
import org.franca.core.franca.FType
import org.franca.core.franca.FTypeCollection
import org.franca.core.franca.FTypeDef
import org.franca.core.franca.FTypeRef
import org.franca.core.franca.FTypedElement
import org.franca.core.franca.FUnionType
import org.genivi.commonapi.core.deployment.DeploymentInterfacePropertyAccessor
import org.genivi.commonapi.core.deployment.DeploymentInterfacePropertyAccessor.DefaultEnumBackingType
import org.genivi.commonapi.core.deployment.DeploymentInterfacePropertyAccessor.EnumBackingType
import org.genivi.commonapi.core.preferences.FPreferences
import org.genivi.commonapi.core.preferences.PreferenceConstants
import org.osgi.framework.FrameworkUtil

import static com.google.common.base.Preconditions.*

class FrancaGeneratorExtensions {

    def String getFullyQualifiedName(FModelElement fModelElement) {
        if (fModelElement.eContainer instanceof FModel)
            return (fModelElement.eContainer as FModel).name + '.' + fModelElement.elementName
        return (fModelElement.eContainer as FModelElement).fullyQualifiedName + '.' + fModelElement.elementName
    }

    def splitCamelCase(String string) {
        string.split("(?<!(^|[A-Z]))(?=[A-Z])|(?<!^)(?=[A-Z][a-z])")
    }

    def FModel getModel(FModelElement fModelElement) {
        if (fModelElement.eContainer instanceof FModel)
            return (fModelElement.eContainer as FModel)
        return (fModelElement.eContainer as FModelElement).model
    }

    def FInterface getContainingInterface(FModelElement fModelElement) {
        if (fModelElement.eContainer == null || fModelElement.eContainer instanceof FModel) {
            return null
        }
        if (fModelElement.eContainer instanceof FInterface) {
            return (fModelElement.eContainer as FInterface)
        }

        return (fModelElement.eContainer as FModelElement).containingInterface
    }

    def FTypeCollection getContainingTypeCollection(FModelElement fModelElement) {
        if (fModelElement.eContainer == null || fModelElement.eContainer instanceof FModel) {
            return null
        }
        if (fModelElement.eContainer instanceof FTypeCollection) {
            return (fModelElement.eContainer as FTypeCollection)
        }

        return (fModelElement.eContainer as FModelElement).containingTypeCollection
    }

    def getDirectoryPath(FModel fModel) {
        fModel.name.replace('.', '/')
    }

    def String getDefineName(FModelElement fModelElement) {
        val defineSuffix = '_' + fModelElement.elementName.splitCamelCase.join('_')

        if (fModelElement.eContainer instanceof FModelElement)
            return (fModelElement.eContainer as FModelElement).defineName + defineSuffix

        return (fModelElement.eContainer as FModel).defineName + defineSuffix
    }

    def getDefineName(FModel fModel) {
        fModel.name.toUpperCase.replace('.', '_')
    }

    def getElementName(FModelElement fModelElement) {
        if(fModelElement.name.nullOrEmpty && fModelElement instanceof FTypeCollection) {
            return "AnonymousTypeCollection"
        }
        else {
            return fModelElement.name
        }
    }


    def private dispatch List<String> getNamespaceAsList(FModel fModel) {
        newArrayList(fModel.name.split("\\."))
    }

    def private dispatch List<String> getNamespaceAsList(FModelElement fModelElement) {
        val namespaceList = fModelElement.eContainer.namespaceAsList
        val isRootElement = fModelElement.eContainer instanceof FModel

        if (!isRootElement)
            namespaceList.add((fModelElement.eContainer as FModelElement).elementName)

        return namespaceList
    }

    def private getSubnamespaceList(FModelElement destination, EObject source) {
        val sourceNamespaceList = source.namespaceAsList
        val destinationNamespaceList = destination.namespaceAsList
        val maxCount = Ints::min(sourceNamespaceList.size, destinationNamespaceList.size)
        var dropCount = 0

        while (dropCount < maxCount &&
            sourceNamespaceList.get(dropCount).equals(destinationNamespaceList.get(dropCount)))
            dropCount = dropCount + 1

        return destinationNamespaceList.drop(dropCount)
    }

    def getRelativeNameReference(FModelElement destination, EObject source) {
        var nameReference = destination.elementName

        if (!destination.eContainer.equals(source)) {
            val subnamespaceList = destination.getSubnamespaceList(source)
            if (!subnamespaceList.empty)
                nameReference = subnamespaceList.join('::') + '::' + nameReference
        }

        return nameReference
    }

    def getHeaderFile(FTypeCollection fTypeCollection) {
        fTypeCollection.elementName + ".h"
    }

    def getHeaderPath(FTypeCollection fTypeCollection) {
        fTypeCollection.model.directoryPath + '/' + fTypeCollection.headerFile
    }

    def getSourceFile(FTypeCollection fTypeCollection) {
        fTypeCollection.elementName + ".cpp"
    }

    def getSourcePath(FTypeCollection fTypeCollection) {
        fTypeCollection.model.directoryPath + '/' + fTypeCollection.sourceFile
    }

    def getProxyBaseHeaderFile(FInterface fInterface) {
        fInterface.elementName + "ProxyBase.h"
    }

    def getProxyBaseHeaderPath(FInterface fInterface) {
        fInterface.model.directoryPath + '/' + fInterface.proxyBaseHeaderFile
    }

    def getProxyBaseClassName(FInterface fInterface) {
        fInterface.elementName + 'ProxyBase'
    }

    def getProxyHeaderFile(FInterface fInterface) {
        fInterface.elementName + "Proxy.h"
    }

    def getProxyHeaderPath(FInterface fInterface) {
        fInterface.model.directoryPath + '/' + fInterface.proxyHeaderFile
    }

    def getStubDefaultHeaderFile(FInterface fInterface) {
        fInterface.elementName + "StubDefault.h"
    }

    def getStubDefaultHeaderPath(FInterface fInterface) {
        fInterface.model.directoryPath + '/' + fInterface.stubDefaultHeaderFile
    }

    def getStubDefaultClassName(FInterface fInterface) {
        fInterface.elementName + 'StubDefault'
    }

    def getStubDefaultSourceFile(FInterface fInterface) {
        fInterface.elementName + "StubDefault.cpp"
    }

    def getStubDefaultSourcePath(FInterface fInterface) {
        fInterface.model.directoryPath + '/' + fInterface.getStubDefaultSourceFile
    }

    def getStubRemoteEventClassName(FInterface fInterface) {
        fInterface.elementName + 'StubRemoteEvent'
    }

    def getStubAdapterClassName(FInterface fInterface) {
        fInterface.elementName + 'StubAdapter'
    }
    
    def getStubCommonAPIClassName(FInterface fInterface) {
        'CommonAPI::Stub<' + fInterface.stubAdapterClassName + ', ' + fInterface.stubRemoteEventClassName + '>'
    }

    def getStubHeaderFile(FInterface fInterface) {
        fInterface.elementName + "Stub.h"
    }

    def getStubHeaderPath(FInterface fInterface) {
        fInterface.model.directoryPath + '/' + fInterface.stubHeaderFile
    }

    def generateSelectiveBroadcastStubIncludes(FInterface fInterface, Collection<String> generatedHeaders,
        Collection<String> libraryHeaders) {
        if (!fInterface.broadcasts.filter[selective.nullOrEmpty].empty) {
            libraryHeaders.add("unordered_set")
        }

        return null
    }

    def generateSelectiveBroadcastProxyIncludes(FInterface fInterface, Collection<String> generatedHeaders,
        Collection<String> libraryHeaders) {
        if (!fInterface.broadcasts.filter[selective.nullOrEmpty].empty) {
            libraryHeaders.add("CommonAPI/types.h")
        }

        return null
    }

    def getStubClassName(FInterface fInterface) {
        fInterface.elementName + 'Stub'
    }

    def hasAttributes(FInterface fInterface) {
        !fInterface.attributes.empty
    }

    def hasBroadcasts(FInterface fInterface) {
        !fInterface.broadcasts.empty
    }

    def hasSelectiveBroadcasts(FInterface fInterface) {
        !fInterface.broadcasts.filter[!selective.nullOrEmpty].empty
    }

    def generateDefinition(FMethod fMethod) {
        fMethod.generateDefinitionWithin(null)
    }

    def generateDefinitionWithin(FMethod fMethod, String parentClassName) {
        var definition = 'void '
        if (FTypeGenerator::isdeprecated(fMethod.comment))
            definition = "COMMONAPI_DEPRECATED " + definition
        if (!parentClassName.nullOrEmpty)
            definition = definition + parentClassName + '::'

        definition = definition + fMethod.elementName + '(' + fMethod.generateDefinitionSignature + ')'

        return definition
    }

    def generateDefinitionSignature(FMethod fMethod) {
        var signature = fMethod.inArgs.map['const ' + getTypeName(fMethod.model) + '& ' + elementName].join(', ')

        if (!fMethod.inArgs.empty)
            signature = signature + ', '

        signature = signature + 'CommonAPI::CallStatus& callStatus'

        if (fMethod.hasError)
            signature = signature + ', ' + fMethod.getErrorNameReference(fMethod.eContainer) + '& methodError'

        if (!fMethod.outArgs.empty)
            signature = signature + ', ' + fMethod.outArgs.map[getTypeName(fMethod.model) + '& ' + elementName].join(', ')

        return signature
    }

    def generateStubSignatureCompatibility(FMethod fMethod) {
        var signature = fMethod.inArgs.map[getTypeName(fMethod.model) + ' ' + elementName].join(', ')
        if (!fMethod.inArgs.empty && (fMethod.hasError || !fMethod.outArgs.empty))
            signature = signature + ', '

        signature = signature + generateStubSignatureErrorsAndOutArgs(fMethod)
        return signature
    }

    def generateStubSignature(FMethod fMethod) {
        var signature = 'const std::shared_ptr<CommonAPI::ClientId> clientId'

        if (!fMethod.inArgs.empty)
            signature = signature + ', '

        signature = signature + fMethod.inArgs.map[getTypeName(fMethod.model) + ' ' + elementName].join(', ')

        if (fMethod.hasError || !fMethod.outArgs.empty)
            signature = signature + ', '

        signature = signature + generateStubSignatureErrorsAndOutArgs(fMethod)

        return signature
    }

    def generateStubSignatureOldStyle(FMethod fMethod) {
        var signature = ''

        signature = signature + fMethod.inArgs.map[getTypeName(fMethod.model) + ' ' + elementName].join(', ')

        if ((fMethod.hasError || !fMethod.outArgs.empty) && !fMethod.inArgs.empty)
            signature = signature + ', '

        signature = signature + generateStubSignatureErrorsAndOutArgs(fMethod)

        return signature
    }

    def generateFireSelectiveSignatur(FBroadcast fBroadcast, FInterface fInterface) {
        var signature = 'const std::shared_ptr<CommonAPI::ClientId> clientId'

        if (!fBroadcast.outArgs.empty)
            signature = signature + ', '

        signature = signature +
            fBroadcast.outArgs.map['const ' + getTypeName(fInterface.model) + '& ' + elementName].join(', ')

        return signature
    }

    def generateSendSelectiveSignatur(FBroadcast fBroadcast, FInterface fInterface, Boolean withDefault) {
        var signature = fBroadcast.outArgs.map['const ' + getTypeName(fInterface.model) + '& ' + elementName].join(', ')

        if (!fBroadcast.outArgs.empty)
            signature = signature + ', '

        signature = signature + 'const std::shared_ptr<CommonAPI::ClientIdList> receivers'

        if (withDefault)
            signature = signature + ' = NULL'

        return signature
    }

    def generateStubSignatureErrorsAndOutArgs(FMethod fMethod) {
        var signature = ''

        if (fMethod.hasError)
            signature = signature + fMethod.getErrorNameReference(fMethod.eContainer) + '& methodError'
        if (fMethod.hasError && !fMethod.outArgs.empty)
            signature = signature + ', '

        if (!fMethod.outArgs.empty)
            signature = signature + fMethod.outArgs.map[getTypeName(fMethod.model) + '& ' + elementName].join(', ')

        return signature
    }

    def generateArgumentsToStubCompatibility(FMethod fMethod) {
        var arguments = fMethod.inArgs.map[elementName].join(', ')

        if ((fMethod.hasError || !fMethod.outArgs.empty) && !fMethod.inArgs.empty)
            arguments = arguments + ', '

        if (fMethod.hasError)
            arguments = arguments + 'methodError'
        if (fMethod.hasError && !fMethod.outArgs.empty)
            arguments = arguments + ', '

        if (!fMethod.outArgs.empty)
            arguments = arguments + fMethod.outArgs.map[elementName].join(', ')

        return arguments
    }

    def generateAsyncDefinition(FMethod fMethod) {
        fMethod.generateAsyncDefinitionWithin(null)
    }

    def generateAsyncDefinitionWithin(FMethod fMethod, String parentClassName) {
        var definition = 'std::future<CommonAPI::CallStatus> '

        if (!parentClassName.nullOrEmpty) {
            definition = definition + parentClassName + '::'
        }

        definition = definition + fMethod.elementName + 'Async(' + fMethod.generateAsyncDefinitionSignature + ')'

        return definition
    }

    def generateAsyncDefinitionSignature(FMethod fMethod) {
        var signature = fMethod.inArgs.map['const ' + getTypeName(fMethod.model) + '& ' + elementName].join(', ')
        if (!fMethod.inArgs.empty) {
            signature = signature + ', '
        }
        return signature + fMethod.asyncCallbackClassName + ' callback'
    }

    def private String getBasicMangledName(FBasicTypeId basicType) {
        switch (basicType) {
            case FBasicTypeId::BOOLEAN:
                return "b"
            case FBasicTypeId::INT8:
                return "i8"
            case FBasicTypeId::UINT8:
                return "u8"
            case FBasicTypeId::INT16:
                return "i16"
            case FBasicTypeId::UINT16:
                return "u16"
            case FBasicTypeId::INT32:
                return "i32"
            case FBasicTypeId::UINT32:
                return "u32"
            case FBasicTypeId::INT64:
                return "i64"
            case FBasicTypeId::UINT64:
                return "u64"
            case FBasicTypeId::FLOAT:
                return "f"
            case FBasicTypeId::DOUBLE:
                return "d"
            case FBasicTypeId::STRING:
                return "s"
            case FBasicTypeId::BYTE_BUFFER:
                return "au8"
        }
    }

    def private dispatch String getDerivedMangledName(FEnumerationType fType) {
        "Ce" + fType.fullyQualifiedName
    }

    def private dispatch String getDerivedMangledName(FMapType fType) {
        "Cm" + fType.fullyQualifiedName
    }

    def private dispatch String getDerivedMangledName(FStructType fType) {
        "Cs" + fType.fullyQualifiedName
    }

    def private dispatch String getDerivedMangledName(FUnionType fType) {
        "Cv" + fType.fullyQualifiedName
    }

    def private dispatch String getDerivedMangledName(FArrayType fType) {
        "Ca" + fType.elementType.mangledName
    }

    def private dispatch String getDerivedMangledName(FTypeDef fType) {
        fType.actualType.mangledName
    }

    def private String getMangledName(FTypeRef fTypeRef) {
        if (fTypeRef.derived != null) {
            return fTypeRef.derived.derivedMangledName
        } else {
            return fTypeRef.predefined.basicMangledName
        }
    }

    def private getBasicAsyncCallbackClassName(FMethod fMethod) {
        fMethod.elementName.toFirstUpper + 'AsyncCallback'
    }

    def private int16Hash(String originalString) {
        val hash32bit = originalString.hashCode

        var hash16bit = hash32bit.bitwiseAnd(0xFFFF)
        hash16bit = hash16bit.bitwiseXor((hash32bit >> 16).bitwiseAnd(0xFFFF))

        return hash16bit
    }

    def private getMangledAsyncCallbackClassName(FMethod fMethod) {
        val baseName = fMethod.basicAsyncCallbackClassName + '_'
        var mangledName = ''
        for (outArg : fMethod.outArgs) {
            mangledName = mangledName + outArg.type.mangledName
        }

        return baseName + mangledName.int16Hash
    }

    def String getAsyncCallbackClassName(FMethod fMethod) {
        if (fMethod.needsMangling) {
            return fMethod.mangledAsyncCallbackClassName
        } else {
            return fMethod.basicAsyncCallbackClassName
        }
    }

    def hasError(FMethod fMethod) {
        fMethod.errorEnum != null || fMethod.errors != null
    }

    def generateASyncTypedefSignature(FMethod fMethod) {
        var signature = 'const CommonAPI::CallStatus&'

        if (fMethod.hasError)
            signature = signature + ', const ' + fMethod.getErrorNameReference(fMethod.eContainer) + '&'

        if (!fMethod.outArgs.empty)
            signature = signature + ', ' + fMethod.outArgs.map['const ' + getTypeName(fMethod.model) + '&'].join(', ')

        return signature
    }

    def needsMangling(FMethod fMethod) {
        for (otherMethod : fMethod.containingInterface.methods) {
            if (otherMethod != fMethod && otherMethod.basicAsyncCallbackClassName == fMethod.basicAsyncCallbackClassName &&
                otherMethod.generateASyncTypedefSignature != fMethod.generateASyncTypedefSignature) {
                return true
            }
        }
        return false
    }

    def getErrorNameReference(FMethod fMethod, EObject source) {
        checkArgument(fMethod.hasError, 'FMethod has no error: ' + fMethod)
        if (fMethod.errorEnum != null) {
            return fMethod.errorEnum.getRelativeNameReference((source as FModelElement).model)
        }

        var errorNameReference = fMethod.errors.errorName
        errorNameReference = (fMethod.eContainer as FInterface).getRelativeNameReference(source) + '::' +
            errorNameReference
        return errorNameReference
    }

    def getClassName(FAttribute fAttribute) {
        fAttribute.elementName.toFirstUpper + 'Attribute'
    }

    def generateGetMethodDefinition(FAttribute fAttribute) {
        fAttribute.generateGetMethodDefinitionWithin(null)
    }

    def generateGetMethodDefinitionWithin(FAttribute fAttribute, String parentClassName) {
        var definition = fAttribute.className + '& '

        if (!parentClassName.nullOrEmpty)
            definition = parentClassName + '::' + definition + parentClassName + '::'

        definition = definition + 'get' + fAttribute.className + '()'

        return definition
    }

    def isReadonly(FAttribute fAttribute) {
        fAttribute.readonly
    }

    def isObservable(FAttribute fAttribute) {
        fAttribute.noSubscriptions == false
    }

    def getStubAdapterClassFireChangedMethodName(FAttribute fAttribute) {
        'fire' + fAttribute.elementName.toFirstUpper + 'AttributeChanged'
    }

    def getStubRemoteEventClassSetMethodName(FAttribute fAttribute) {
        'onRemoteSet' + fAttribute.elementName.toFirstUpper + 'Attribute'
    }

    def getStubRemoteEventClassChangedMethodName(FAttribute fAttribute) {
        'onRemote' + fAttribute.elementName.toFirstUpper + 'AttributeChanged'
    }

    def getStubClassGetMethodName(FAttribute fAttribute) {
        'get' + fAttribute.elementName.toFirstUpper + 'Attribute'
    }

    def getClassName(FBroadcast fBroadcast) {
        var className = fBroadcast.elementName.toFirstUpper

        if (!fBroadcast.selective.nullOrEmpty)
            className = className + 'Selective'

        className = className + 'Event'

        return className
    }

    def generateGetMethodDefinition(FBroadcast fBroadcast) {
        fBroadcast.generateGetMethodDefinitionWithin(null)
    }

    def generateGetMethodDefinitionWithin(FBroadcast fBroadcast, String parentClassName) {
        var definition = fBroadcast.className + '& '

        if (!parentClassName.nullOrEmpty)
            definition = parentClassName + '::' + definition + parentClassName + '::'

        definition = definition + 'get' + fBroadcast.className + '()'

        return definition
    }

    def getStubAdapterClassFireEventMethodName(FBroadcast fBroadcast) {
        'fire' + fBroadcast.elementName.toFirstUpper + 'Event'
    }

    def getStubAdapterClassFireSelectiveMethodName(FBroadcast fBroadcast) {
        'fire' + fBroadcast.elementName.toFirstUpper + 'Selective';
    }

    def getStubAdapterClassSendSelectiveMethodName(FBroadcast fBroadcast) {
        'send' + fBroadcast.elementName.toFirstUpper + 'Selective';
    }

    def getSubscribeSelectiveMethodName(FBroadcast fBroadcast) {
        'subscribeFor' + fBroadcast.elementName + 'Selective';
    }

    def getUnsubscribeSelectiveMethodName(FBroadcast fBroadcast) {
        'unsubscribeFrom' + fBroadcast.elementName + 'Selective';
    }

    def getSubscriptionChangedMethodName(FBroadcast fBroadcast) {
        'on' + fBroadcast.elementName.toFirstUpper + 'SelectiveSubscriptionChanged';
    }

    def getSubscriptionRequestedMethodName(FBroadcast fBroadcast) {
        'on' + fBroadcast.elementName.toFirstUpper + 'SelectiveSubscriptionRequested';
    }

    def getStubAdapterClassSubscribersMethodName(FBroadcast fBroadcast) {
        'getSubscribersFor' + fBroadcast.elementName.toFirstUpper + 'Selective';
    }

    def getStubAdapterClassSubscriberListPropertyName(FBroadcast fBroadcast) {
        'subscribersFor' + fBroadcast.elementName.toFirstUpper + 'Selective_';
    }

    def getStubSubscribeSignature(FBroadcast fBroadcast) {
        'const std::shared_ptr<CommonAPI::ClientId> clientId, bool& success'
    }

    def boolean isSelective(FBroadcast fBroadcast) {
        return !fBroadcast.selective.nullOrEmpty
    }

    def getTypeName(FTypedElement element, EObject source) {
        var typeName = element.type.getNameReference(source)

        if (element.type.derived instanceof FStructType && (element.type.derived as FStructType).hasPolymorphicBase)
            typeName = 'std::shared_ptr<' + typeName + '>'

        if ("[]".equals(element.array)) {
            if (element.type.derived instanceof FStructType && (element.type.derived as FStructType).hasPolymorphicBase) {
                typeName = 'std::vector<std::shared_ptr<' + element.type.getNameReference(source) + '>>'
            } else {
                typeName = 'std::vector<' + element.type.getNameReference(source) + '>'
            }
        }

        return typeName
    }

    def boolean isPolymorphic(FTypeRef typeRef) {
        return (typeRef.derived != null && typeRef.derived instanceof FStructType && (typeRef.derived as FStructType).polymorphic)
    }

    def getNameReference(FTypeRef destination, EObject source) {
        if (destination.derived != null)
            return destination.derived.getRelativeNameReference(source)
        return destination.predefined.primitiveTypeName
    }

    def getErrorName(FEnumerationType fMethodErrors) {
        checkArgument(fMethodErrors.eContainer instanceof FMethod, 'Not FMethod errors')
        (fMethodErrors.eContainer as FMethod).elementName + 'Error'
    }

    def getBackingType(FEnumerationType fEnumerationType, DeploymentInterfacePropertyAccessor deploymentAccessor) {
        if (deploymentAccessor.getEnumBackingType(fEnumerationType) == EnumBackingType::UseDefault) {
            if (fEnumerationType.containingInterface != null) {
                switch (deploymentAccessor.getDefaultEnumBackingType(fEnumerationType.containingInterface)) {
                    case DefaultEnumBackingType::UInt8:
                        return FBasicTypeId::UINT8
                    case DefaultEnumBackingType::UInt16:
                        return FBasicTypeId::UINT16
                    case DefaultEnumBackingType::UInt32:
                        return FBasicTypeId::UINT32
                    case DefaultEnumBackingType::UInt64:
                        return FBasicTypeId::UINT64
                    case DefaultEnumBackingType::Int8:
                        return FBasicTypeId::INT8
                    case DefaultEnumBackingType::Int16:
                        return FBasicTypeId::INT16
                    case DefaultEnumBackingType::Int32:
                        return FBasicTypeId::INT32
                    case DefaultEnumBackingType::Int64:
                        return FBasicTypeId::INT64
                }
            }
        }
        switch (deploymentAccessor.getEnumBackingType(fEnumerationType)) {
            case EnumBackingType::UInt8:
                return FBasicTypeId::UINT8
            case EnumBackingType::UInt16:
                return FBasicTypeId::UINT16
            case EnumBackingType::UInt32:
                return FBasicTypeId::UINT32
            case EnumBackingType::UInt64:
                return FBasicTypeId::UINT64
            case EnumBackingType::Int8:
                return FBasicTypeId::INT8
            case EnumBackingType::Int16:
                return FBasicTypeId::INT16
            case EnumBackingType::Int32:
                return FBasicTypeId::INT32
            case EnumBackingType::Int64:
                return FBasicTypeId::INT64
        }
        return FBasicTypeId::INT32
    }

    def getPrimitiveTypeName(FBasicTypeId fBasicTypeId) {
        switch fBasicTypeId {
            case FBasicTypeId::BOOLEAN: "bool"
            case FBasicTypeId::INT8: "int8_t"
            case FBasicTypeId::UINT8: "uint8_t"
            case FBasicTypeId::INT16: "int16_t"
            case FBasicTypeId::UINT16: "uint16_t"
            case FBasicTypeId::INT32: "int32_t"
            case FBasicTypeId::UINT32: "uint32_t"
            case FBasicTypeId::INT64: "int64_t"
            case FBasicTypeId::UINT64: "uint64_t"
            case FBasicTypeId::FLOAT: "float"
            case FBasicTypeId::DOUBLE: "double"
            case FBasicTypeId::STRING: "std::string"
            case FBasicTypeId::BYTE_BUFFER: "CommonAPI::ByteBuffer"
            default: throw new IllegalArgumentException("Unsupported basic type: " + fBasicTypeId.getName)
        }
    }

    def String typeStreamSignature(FTypeRef fTypeRef, DeploymentInterfacePropertyAccessor deploymentAccessor, FField forThisElement) {
        if (forThisElement.array != null && forThisElement.array.equals("[]")) {
            var String ret = ""
            ret = ret + "typeOutputStream.beginWriteVectorType();\n"
            ret = ret + fTypeRef.actualTypeStreamSignature(deploymentAccessor)
            ret = ret + "typeOutputStream.endWriteVectorType();\n"
            return ret
        }
        return fTypeRef.actualTypeStreamSignature(deploymentAccessor)
    }

    def String actualTypeStreamSignature(FTypeRef fTypeRef, DeploymentInterfacePropertyAccessor deploymentAccessor) {
        if (fTypeRef.derived != null) {
            return fTypeRef.derived.typeStreamFTypeSignature(deploymentAccessor)
        }

        return fTypeRef.predefined.basicTypeStreamSignature
    }

    def private String getBasicTypeStreamSignature(FBasicTypeId fBasicTypeId) {
        switch fBasicTypeId {
            case FBasicTypeId::BOOLEAN: return "typeOutputStream.writeBoolType();"
            case FBasicTypeId::INT8: return "typeOutputStream.writeInt8Type();"
            case FBasicTypeId::UINT8: return "typeOutputStream.writeUInt8Type();"
            case FBasicTypeId::INT16: return "typeOutputStream.writeInt16Type();"
            case FBasicTypeId::UINT16: return "typeOutputStream.writeUInt16Type();"
            case FBasicTypeId::INT32: return "typeOutputStream.writeInt32Type();"
            case FBasicTypeId::UINT32: return "typeOutputStream.writeUInt32Type();"
            case FBasicTypeId::INT64: return "typeOutputStream.writeInt64Type();"
            case FBasicTypeId::UINT64: return "typeOutputStream.writeUInt64Type();"
            case FBasicTypeId::FLOAT: return "typeOutputStream.writeFloatType();"
            case FBasicTypeId::DOUBLE: return "typeOutputStream.writeDoubleType();"
            case FBasicTypeId::STRING: return "typeOutputStream.writeStringType();"
            case FBasicTypeId::BYTE_BUFFER: return "typeOutputStream.writeByteBufferType();"
        }
    }

    def private dispatch String typeStreamFTypeSignature(FTypeDef fTypeDef,
        DeploymentInterfacePropertyAccessor deploymentAccessor) {
        return fTypeDef.actualType.actualTypeStreamSignature(deploymentAccessor)
    }

    def private dispatch String typeStreamFTypeSignature(FArrayType fArrayType,
        DeploymentInterfacePropertyAccessor deploymentAccessor) {
        return 'typeOutputStream.beginWriteVectorType();\n' +
            fArrayType.elementType.actualTypeStreamSignature(deploymentAccessor) + '\n' +
            'typeOutputStream.endWriteVectorType();'
    }

    def private dispatch String typeStreamFTypeSignature(FMapType fMap,
        DeploymentInterfacePropertyAccessor deploymentAccessor) {
        return 'typeOutputStream.beginWriteMapType();\n' + fMap.keyType.actualTypeStreamSignature(deploymentAccessor) + '\n' +
            fMap.valueType.actualTypeStreamSignature(deploymentAccessor) + '\n' + 'typeOutputStream.endWriteMapType();'
    }

    def private dispatch String typeStreamFTypeSignature(FStructType fStructType,
        DeploymentInterfacePropertyAccessor deploymentAccessor) {
        return 'typeOutputStream.beginWriteStructType();\n' +
            fStructType.getElementsTypeStreamSignature(deploymentAccessor) + '\n' +
            'typeOutputStream.endWriteStructType();'
    }

    def private dispatch String typeStreamFTypeSignature(FEnumerationType fEnumerationType,
        DeploymentInterfacePropertyAccessor deploymentAccessor) {
        return fEnumerationType.getBackingType(deploymentAccessor).basicTypeStreamSignature
    }

    def private dispatch String typeStreamFTypeSignature(FUnionType fUnionType,
        DeploymentInterfacePropertyAccessor deploymentAccessor) {
        return 'typeOutputStream.writeVariantType();'
    }

    def private String getElementsTypeStreamSignature(FStructType fStructType,
        DeploymentInterfacePropertyAccessor deploymentAccessor) {
        var signature = fStructType.elements.map[type.typeStreamSignature(deploymentAccessor, it)].join

        if (fStructType.base != null)
            signature = fStructType.base.getElementsTypeStreamSignature(deploymentAccessor) + signature

        return signature
    }

    def List<FType> getDirectlyReferencedTypes(FType type) {
        val directlyReferencedTypes = newLinkedList

        directlyReferencedTypes.addFTypeDirectlyReferencedTypes(type)

        return directlyReferencedTypes
    }

    def private dispatch addFTypeDirectlyReferencedTypes(List<FType> list, FStructType fType) {
        list.addAll(fType.elements.filter[type.derived != null].map[type.derived])

        if (fType.base != null)
            list.add(fType.base)
    }

    def private dispatch addFTypeDirectlyReferencedTypes(List<FType> list, FEnumerationType fType) {
        if (fType.base != null)
            list.add(fType.base)
    }

    def private dispatch addFTypeDirectlyReferencedTypes(List<FType> list, FArrayType fType) {
        if (fType.elementType.derived != null)
            list.add(fType.elementType.derived)
    }

    def private dispatch addFTypeDirectlyReferencedTypes(List<FType> list, FUnionType fType) {
        list.addAll(fType.elements.filter[type.derived != null].map[type.derived])

        if (fType.base != null)
            list.add(fType.base)
    }

    def private dispatch addFTypeDirectlyReferencedTypes(List<FType> list, FMapType fType) {
        if (fType.keyType.derived != null)
            list.add(fType.keyType.derived)

        if (fType.valueType.derived != null)
            list.add(fType.valueType.derived)
    }

    def private dispatch addFTypeDirectlyReferencedTypes(List<FType> list, FTypeDef fType) {
        if (fType.actualType.derived != null)
            list.add(fType.actualType.derived)
    }

    def boolean hasPolymorphicBase(FStructType fStructType) {
        if (fStructType.isPolymorphic)
            return true;

        return fStructType.base != null && fStructType.base.hasPolymorphicBase
    }

    def getSerialId(FStructType fStructType) {
        val hasher = Hashing::murmur3_32.newHasher
        hasher.putFTypeObject(fStructType);
        return hasher.hash.asInt
    }

    def private dispatch void putFTypeObject(Hasher hasher, FStructType fStructType) {
        if (fStructType.base != null)
            hasher.putFTypeObject(fStructType.base)

        hasher.putString('FStructType', Charsets::UTF_8)
        fStructType.elements.forEach [
            hasher.putFTypeRef(type)
            // avoid cases where the positions of 2 consecutive elements of the same type are switched
            hasher.putString(elementName, Charsets::UTF_8)
        ]
    }

    def private dispatch void putFTypeObject(Hasher hasher, FEnumerationType fEnumerationType) {
        if (fEnumerationType.base != null)
            hasher.putFTypeObject(fEnumerationType.base)

        hasher.putString('FEnumerationType', Charsets::UTF_8)
        hasher.putInt(fEnumerationType.enumerators.size)
    }

    def private dispatch void putFTypeObject(Hasher hasher, FArrayType fArrayType) {
        hasher.putString('FArrayType', Charsets::UTF_8)
        hasher.putFTypeRef(fArrayType.elementType)
    }

    def private dispatch void putFTypeObject(Hasher hasher, FUnionType fUnionType) {
        if (fUnionType.base != null)
            hasher.putFTypeObject(fUnionType.base)

        hasher.putString('FUnionType', Charsets::UTF_8)
        fUnionType.elements.forEach[hasher.putFTypeRef(type)]
    }

    def private dispatch void putFTypeObject(Hasher hasher, FMapType fMapType) {
        hasher.putString('FMapType', Charsets::UTF_8)
        hasher.putFTypeRef(fMapType.keyType)
        hasher.putFTypeRef(fMapType.valueType)
    }

    def private dispatch void putFTypeObject(Hasher hasher, FTypeDef fTypeDef) {
        hasher.putFTypeRef(fTypeDef.actualType)
    }

    def private void putFTypeRef(Hasher hasher, FTypeRef fTypeRef) {
        if (fTypeRef.derived != null)
            hasher.putFTypeObject(fTypeRef.derived)
        else
            hasher.putString(fTypeRef.predefined.getName, Charsets::UTF_8);
    }

    def boolean hasDerivedFStructTypes(FStructType fStructType) {
        return EcoreUtil.UsageCrossReferencer::find(fStructType, fStructType.model.eResource.resourceSet).exists [
            EObject instanceof FStructType && (EObject as FStructType).base == fStructType
        ]
    }

    def getDerivedFStructTypes(FStructType fStructType) {
        return EcoreUtil.UsageCrossReferencer::find(fStructType, fStructType.model.eResource.resourceSet).map[EObject].
            filter[it instanceof FStructType].map[it as FStructType].filter[base == fStructType]
    }

    def generateCppNamespace(FModel fModel) '''
    «fModel.namespaceAsList.map[toString].join("::")»::'''

    def generateNamespaceBeginDeclaration(FModel fModel) '''
        «FOR subnamespace : fModel.namespaceAsList»
            namespace «subnamespace» {
        «ENDFOR»
    '''

    def generateNamespaceEndDeclaration(FModel fModel) '''
        «FOR subnamespace : fModel.namespaceAsList.reverse»
            } // namespace «subnamespace»
        «ENDFOR»
    '''

    def isFireAndForget(FMethod fMethod) {
        return !fMethod.fireAndForget.nullOrEmpty
    }

    def getFilePath(Resource resource) {
        if (resource.URI.file)
            return resource.URI.toFileString

        val platformPath = new Path(resource.URI.toPlatformString(true))
        val file = ResourcesPlugin::getWorkspace().getRoot().getFile(platformPath);

        return file.location.toString
    }

    def getHeader(FModel model, IResource res) {
        if (FrameworkUtil::getBundle(this.getClass()) != null) {
            var returnValue = DefaultScope::INSTANCE.getNode(PreferenceConstants::SCOPE).get(PreferenceConstants::P_LICENSE, "")
            returnValue = InstanceScope::INSTANCE.getNode(PreferenceConstants::SCOPE).get(PreferenceConstants::P_LICENSE, returnValue)
            returnValue = FPreferences::instance.getPreference(res, PreferenceConstants::P_LICENSE, returnValue)
            return returnValue
        }
        return ""
    }

    def getFrancaVersion() {
        val bundle = FrameworkUtil::getBundle(FrancaGeneratorExtensions)
        val bundleContext = bundle.getBundleContext();
        for (b : bundleContext.bundles) {
            if (b.symbolicName.equals("org.franca.core")) {
                return b.version.toString
            }
        }
    }

    def static getCoreVersion() {
        val bundle = FrameworkUtil::getBundle(FrancaGeneratorExtensions)
        val bundleContext = bundle.getBundleContext();
        for (b : bundleContext.bundles) {
            if (b.symbolicName.equals("org.genivi.commonapi.core")) {
                return b.version.toString
            }
        }
    }

    def generateCommonApiLicenseHeader(FModelElement model, IResource modelid) '''
        /*
        * This file was generated by the CommonAPI Generators.
        * Used org.genivi.commonapi.core «FrancaGeneratorExtensions::getCoreVersion()».
        * Used org.franca.core «getFrancaVersion()».
        *
        «getCommentedString(getHeader(model.model, modelid))»
        */
    '''

    def getCommentedString(String string) {
        val lines = string.split("\n");
        var builder = new StringBuilder();
        for (String line : lines) {
            builder.append("* " + line + "\n");
        }
        return builder.toString()
    }

    def stubManagedSetName(FInterface fInterface) {
        'registered' + fInterface.elementName + 'Instances'
    }

    def stubManagedSetGetterName(FInterface fInterface) {
        'get' + fInterface.elementName + 'Instances'
    }

    def stubRegisterManagedName(FInterface fInterface) {
        'registerManagedStub' + fInterface.elementName
    }

    def stubRegisterManagedAutoName(FInterface fInterface) {
        'registerManagedStub' + fInterface.elementName + 'AutoInstance'
    }

    def stubRegisterManagedMethod(FInterface fInterface) {
        'bool ' + fInterface.stubRegisterManagedName + '(std::shared_ptr<' + fInterface.stubClassName + '>, const std::string&)'
    }

    def stubRegisterManagedMethodImpl(FInterface fInterface) {
        fInterface.stubRegisterManagedName + '(std::shared_ptr<' + fInterface.stubClassName + '> stub, const std::string& instance)'
    }    

    def stubDeregisterManagedName(FInterface fInterface) {
        'deregisterManagedStub' + fInterface.elementName
    }

    def proxyManagerGetterName(FInterface fInterface) {
        'getProxyManager' + fInterface.elementName
    }

    def proxyManagerMemberName(FInterface fInterface) {
        'proxyManager' + fInterface.elementName + '_'
    }

    def EList<FMethod> getInheritedMethods(FInterface fInterface) {
        if(fInterface.base == null) {
            return new BasicEList()
        }

        val methods = fInterface.base.methods
        methods.addAll(fInterface.base.inheritedMethods)

        return methods
    }

    def EList<FAttribute> getInheritedAttributes(FInterface fInterface) {
        if(fInterface.base == null) {
            return new BasicEList()
        }

        val attributes = fInterface.base.attributes
        attributes.addAll(fInterface.base.inheritedAttributes)

        return attributes
    }

    def EList<FBroadcast> getInheritedBroadcasts(FInterface fInterface) {
        if(fInterface.base == null) {
            return new BasicEList()
        }

        val broadcasts = fInterface.base.broadcasts
        broadcasts.addAll(fInterface.base.inheritedBroadcasts)

        return broadcasts
    }
}