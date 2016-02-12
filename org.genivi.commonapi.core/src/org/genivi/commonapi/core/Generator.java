package org.genivi.commonapi.core;

import java.util.ArrayList;
import java.util.List;

import org.eclipse.core.resources.IResource;
import org.eclipse.xtext.generator.IFileSystemAccess;
import org.franca.core.franca.FModel;
import org.franca.deploymodel.dsl.fDeploy.FDInterface;
import org.franca.deploymodel.dsl.fDeploy.FDProvider;
import org.franca.deploymodel.dsl.fDeploy.FDTypes;
import org.genivi.commonapi.core.generator.FrancaGenerator;
import org.genivi.commonapi.cmdline.GeneratorInterface;

import com.google.inject.Inject;

public class Generator implements GeneratorInterface {

	@Inject
	FrancaGenerator generator;


	public void generate(FModel fModel, List<FDInterface> deployedInterfaces,
			IFileSystemAccess fileSystemAccess, IResource res) {
		generator.doGenerateComponents(fModel, deployedInterfaces, new ArrayList<FDTypes>(),
				new ArrayList<FDProvider>(),fileSystemAccess, res);
	}

}
