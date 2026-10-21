cmake_minimum_required(VERSION 3.28)
project(NekoTuneStarcape LANGUAGES NONE)
include(CTest)
file(GLOB_RECURSE theme_files CONFIGURE_DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/theme/*")
set(package "${CMAKE_BINARY_DIR}/packages/nekotune.theme-starcape.nktheme.zip")
add_custom_command(OUTPUT "${package}"
    COMMAND "${CMAKE_COMMAND}" -E make_directory "${CMAKE_BINARY_DIR}/packages"
    COMMAND "${CMAKE_COMMAND}" "-DOUTPUT=${package}" -P "${CMAKE_CURRENT_SOURCE_DIR}/cmake/Package.cmake"
    WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/theme"
    DEPENDS ${theme_files} VERBATIM)
add_custom_target(extension_package ALL DEPENDS "${package}")
if(BUILD_TESTING)
    find_package(Python3 REQUIRED COMPONENTS Interpreter)
    add_test(NAME theme_package COMMAND "${Python3_EXECUTABLE}"
        "${CMAKE_CURRENT_SOURCE_DIR}/tests/validate_package.py" "${package}")
endif()
