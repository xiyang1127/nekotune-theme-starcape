# Opt in with NEKOTUNE_EXTERNAL_TESTS_DIR=/path/to/NekoTune-extensions/starcape/tests.
# The theme is packaged with the host SDK's archiver so the test imports a real .nktheme.zip.
file(GLOB_RECURSE STARCAPE_FILES CONFIGURE_DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/../theme/*")
set(STARCAPE_PACKAGE "${CMAKE_CURRENT_BINARY_DIR}/nekotune.theme-starcape.nktheme.zip")
add_custom_command(OUTPUT "${STARCAPE_PACKAGE}"
    COMMAND "${CMAKE_COMMAND}" "-DOUTPUT=${STARCAPE_PACKAGE}" -P "${CMAKE_SOURCE_DIR}/sdk/cmake/NekoTunePackage.cmake"
    WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/../theme"
    DEPENDS ${STARCAPE_FILES}
    VERBATIM)
add_custom_target(nekotune_starcape_package DEPENDS "${STARCAPE_PACKAGE}")
add_executable(nekotune_starcape_test integration_test.cpp "${CMAKE_SOURCE_DIR}/frontend/qt-qml/resources.qrc")
target_include_directories(nekotune_starcape_test PRIVATE "${CMAKE_SOURCE_DIR}/tests")
target_link_libraries(nekotune_starcape_test PRIVATE nekotune_core nekotune_frontend Qt6::Test Qt6::Quick Qt6::QuickControls2)
target_compile_definitions(nekotune_starcape_test PRIVATE STARCAPE_PACKAGE="${STARCAPE_PACKAGE}")
add_dependencies(nekotune_starcape_test nekotune_starcape_package)
add_test(NAME nekotune_starcape_test COMMAND nekotune_starcape_test)
set_tests_properties(nekotune_starcape_test PROPERTIES ENVIRONMENT "QT_QPA_PLATFORM=offscreen;QT_QUICK_BACKEND=software")
