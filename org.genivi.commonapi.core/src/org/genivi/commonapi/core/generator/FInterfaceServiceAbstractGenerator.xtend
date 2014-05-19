/* Copyright (C) 2013 BMW Group
 * Author: Manfred Bathelt (manfred.bathelt@bmw.de)
 * Author: Juergen Gehring (juergen.gehring@bmw.de)
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */
package org.genivi.commonapi.core.generator

import javax.inject.Inject
import org.eclipse.xtext.generator.IFileSystemAccess
import org.franca.core.franca.FAttribute
import org.franca.core.franca.FInterface
import org.eclipse.core.resources.IResource

class FInterfaceServiceAbstractGenerator {
    @Inject private extension FrancaGeneratorExtensions

    def generateServiceAbstract(FInterface fInterface, IFileSystemAccess fileSystemAccess, IResource modelid) {
        fileSystemAccess.generateFile(fInterface.stubDefaultHeaderPath, fInterface.generateStubDefaultHeader(modelid))
    }

    def getStubDefaultHeaderFile(FInterface fInterface) {
        fInterface.elementName + "ServiceAbstract.h"
    }

    def getStubDefaultHeaderPath(FInterface fInterface) {
        fInterface.model.directoryPath + '/' + fInterface.stubDefaultHeaderFile
    }

    def getStubDefaultClassName(FInterface fInterface) {
        fInterface.elementName + 'ServiceAbstract'
    }

    def getStubDefaultSourceFile(FInterface fInterface) {
        fInterface.elementName + "ServiceAbstract.cpp"
    }

    def private generateStubDefaultHeader(FInterface fInterface, IResource modelid) '''
        «generateCommonApiLicenseHeader(fInterface, modelid)»
        «FTypeGenerator::generateComments(fInterface, false)»
        #pragma once

        #include <«fInterface.stubHeaderPath»>
        #include <sstream>
        #include <assert.h>

        «fInterface.model.generateNamespaceBeginDeclaration»

        /**
         * Provides a default implementation for «fInterface.stubRemoteEventClassName» and
         * «fInterface.stubClassName». Method callbacks have an empty implementation,
         * remote set calls on attributes will always change the value of the attribute
         * to the one received.
         *
         * Override this stub if you only want to provide a subset of the functionality
         * that would be defined for this service, and/or if you do not need any non-default
         * behaviour.
         */
        class «fInterface.stubDefaultClassName» : public «fInterface.stubClassName» {
         public:
            «fInterface.stubDefaultClassName»() :
                «IF !fInterface.managedInterfaces.empty»
                    autoInstanceCounter_(0),
                «ENDIF»
                remoteEventHandler_(this) {
        }

            «fInterface.stubRemoteEventClassName»* initStubAdapter(const std::shared_ptr<«fInterface.stubAdapterClassName»>& stubAdapter) {
            stubAdapters_.push_back(stubAdapter);
            return &remoteEventHandler_;
        }


        «FOR attribute : fInterface.attributes»
            virtual const «attribute.getTypeName(fInterface.model)»& «attribute.stubClassGetMethodName»() = 0 ;

            «IF attribute.isObservable»
            void «attribute.getStubDefaultClassNotifyName»() {
                for (auto& stubAdapter_ : stubAdapters_)
	                stubAdapter_->«attribute.stubAdapterClassFireChangedMethodName»(«attribute.stubClassGetMethodName»());
            }
            «ENDIF»

            const «attribute.getTypeName(fInterface.model)»& «attribute.stubClassGetMethodName»(const std::shared_ptr<CommonAPI::ClientId> clientId) {
                return «attribute.stubClassGetMethodName»();
            }

            «IF !attribute.readonly»
                void «attribute.stubDefaultClassSetMethodName»(const std::shared_ptr<CommonAPI::ClientId> clientId, «attribute.getTypeName(fInterface.model)» value) {
                    «attribute.stubDefaultClassSetMethodName»(value);
                }

                virtual void «attribute.stubDefaultClassSetMethodName»(«attribute.getTypeName(fInterface.model)» value) = 0;

            «ENDIF»

        «ENDFOR»
        
        «FOR method : fInterface.methods»
            «FTypeGenerator::generateComments(method, false)»
            virtual void «method.elementName»(«method.generateStubSignature») {
                // Call old style methods in default 
                return «method.elementName»(«method.generateArgumentsToStubCompatibility»);
            }
            virtual void «method.elementName»(«method.generateStubSignatureOldStyle») = 0;

        «ENDFOR»

        «FOR broadcast : fInterface.broadcasts»
            «FTypeGenerator::generateComments(broadcast, false)»
            «IF !broadcast.selective.nullOrEmpty»
                void «broadcast.stubAdapterClassFireSelectiveMethodName»(«generateSendSelectiveSignatur(broadcast, fInterface, false)») {
                    for (auto& stubAdapter_ : stubAdapters_)
                    	stubAdapter_->«broadcast.stubAdapterClassSendSelectiveMethodName»(«broadcast.outArgs.map[elementName].join(', ')»«IF(!broadcast.outArgs.empty)», «ENDIF»receivers);
                }
                void «broadcast.subscriptionChangedMethodName»(const std::shared_ptr<CommonAPI::ClientId> clientId, const CommonAPI::SelectiveBroadcastSubscriptionEvent event) {
                    // No operation in default
                }
                bool «broadcast.subscriptionRequestedMethodName»(const std::shared_ptr<CommonAPI::ClientId> clientId) {
                    // Accept in default
                    return true;
                }
                std::shared_ptr<CommonAPI::ClientIdList> const «broadcast.stubAdapterClassSubscribersMethodName»() {
                    return (stubAdapter_->«broadcast.stubAdapterClassSubscribersMethodName»());
                }

            «ELSE»
                void «broadcast.stubAdapterClassFireEventMethodName»(«broadcast.outArgs.map['const ' + getTypeName(fInterface.model) + '& ' + elementName].join(', ')») {
                    for (auto& stubAdapter_ : stubAdapters_)
	                    stubAdapter_->«broadcast.stubAdapterClassFireEventMethodName»(«broadcast.outArgs.map[elementName].join(', ')»);
                }
            «ENDIF»
        «ENDFOR»

            «FOR managed : fInterface.managedInterfaces»
            bool «managed.stubRegisterManagedAutoName»(std::shared_ptr<«managed.stubClassName»> stub) {
                autoInstanceCounter_++;
                std::stringstream ss;
                ss << stubAdapter_->getInstanceId() << ".i" << autoInstanceCounter_;
                std::string instance = ss.str();
                return stubAdapter_->«managed.stubRegisterManagedName»(stub, instance);
            }
            bool «managed.stubRegisterManagedMethodImpl» {
                return stubAdapter_->«managed.stubRegisterManagedName»(stub, instance);
            }
            bool «managed.stubDeregisterManagedName»(const std::string& instance) {
                return stubAdapter_->«managed.stubDeregisterManagedName»(instance);
            }
            std::set<std::string>& «managed.stubManagedSetGetterName»() {
                return stubAdapter_->«managed.stubManagedSetGetterName»();
            }
            «ENDFOR»

         protected:
            «FOR attribute : fInterface.attributes»
                «FTypeGenerator::generateComments(attribute, false)»
            «ENDFOR»
            std::vector<std::shared_ptr<«fInterface.stubAdapterClassName»>> stubAdapters_;
         private:
            class RemoteEventHandler: public «fInterface.stubRemoteEventClassName» {
             public:
                RemoteEventHandler(«fInterface.stubDefaultClassName»* defaultStub) :
                defaultStub_(defaultStub) {
        }

                «FOR attribute : fInterface.attributes»
                    «FTypeGenerator::generateComments(attribute, false)»
                    «IF !attribute.readonly»
                void «attribute.stubRemoteEventClassChangedMethodName»() {
                	assert(false);  // we don't expect this method to be called
                }

                bool «attribute.stubRemoteEventClassSetMethodName»(«attribute.getTypeName(fInterface.model)» value) {
                    defaultStub_->«attribute.stubDefaultClassSetMethodName»(value);
                    return false;	// We let the service implementation take care of triggering the "property changed"" notifications
                }

                bool «attribute.stubRemoteEventClassSetMethodName»(const std::shared_ptr<CommonAPI::ClientId> clientId, «attribute.getTypeName(fInterface.model)» value) {
                    return «attribute.stubRemoteEventClassSetMethodName»(value);
                }

                    «ENDIF»

                «ENDFOR»

             private:
                «fInterface.stubDefaultClassName»* defaultStub_;
            };

            RemoteEventHandler remoteEventHandler_;
            «IF !fInterface.managedInterfaces.empty»
                uint32_t autoInstanceCounter_;
            «ENDIF»

        };

        «fInterface.model.generateNamespaceEndDeclaration»

    '''

    def private getStubDefaultClassSetMethodName(FAttribute fAttribute) {
        'set' + fAttribute.elementName.toFirstUpper + 'Attribute'
    }

    def private getStubDefaultClassNotifyName(FAttribute fAttribute) {
        'fire' + fAttribute.name.toFirstUpper + 'AttributeChangedNotification'
    }

}
