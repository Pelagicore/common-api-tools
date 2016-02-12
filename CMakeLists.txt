
cmake_minimum_required(VERSION 2.6)

project(common-api-tools)

find_package(CommonAPICodeGenFramework)

import_maven_repository(common-api-cmdline)

# We build the core code generator, which we then install in the local Maven repository, which we export so that it can 
# be used by other packages
add_maven_package(core-codegen ${CMAKE_CURRENT_SOURCE_DIR}/org.genivi.commonapi.core "")

export_maven_repository(common-api-tools)

# Write and install an ugly dummy file to ensure that CMake create an "install" target. FIXME
file(WRITE ${CMAKE_CURRENT_BINARY_DIR}/dummy "")
install(FILES ${CMAKE_CURRENT_BINARY_DIR}/dummy DESTINATION share)
