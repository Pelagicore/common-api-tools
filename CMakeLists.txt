
project(common-api-dbus-tools)

find_package(CommonAPICodeGenFramework)
import_maven_repository(common-api-cmdline)

# We build the "almost-vanilla" core code generator, which we then install in the local Maven repository, which we export so that it can 
# be used by other packages
add_maven_package(core-codegen ${CMAKE_CURRENT_SOURCE_DIR}/org.genivi.commonapi.core "")

export_maven_repository(common-api-tools)
