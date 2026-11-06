cmake_minimum_required(VERSION 3.14)
project(runner LANGUAGES CXX)

# Define the application target. To change its name, change BINARY_NAME in the
# top-level CMakeLists.txt, not the value here, or `flutter run` will no longer
# work.
#
# Any new source files that you add to the application should be added here.
add_executable(${BINARY_NAME} WIN32
  "flutter_window.cpp"
  "main.cpp"
  "utils.cpp"
  "win32_window.cpp"
  "windows_reminders.cpp"
  "notification_identity.cpp"
  "../../companion/windows_host/protocol.cpp"
  "../../companion/windows_host/pipe_transport.cpp"
  "../../companion/windows_host/peer_identity.cpp"
  "${FLUTTER_MANAGED_DIR}/generated_plugin_registrant.cc"
  "Runner.rc"
  "runner.exe.manifest"
)

# Apply the standard set of build settings. This can be removed for applications
# that need different build settings.
apply_standard_settings(${BINARY_NAME})

# Add preprocessor definitions for the build version.
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION=\"${FLUTTER_VERSION}\"")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_MAJOR=${FLUTTER_VERSION_MAJOR}")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_MINOR=${FLUTTER_VERSION_MINOR}")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_PATCH=${FLUTTER_VERSION_PATCH}")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_BUILD=${FLUTTER_VERSION_BUILD}")

# Disable Windows macros that collide with C++ standard library functions.
target_compile_definitions(${BINARY_NAME} PRIVATE "NOMINMAX")

# Add dependency libraries and include directories. Add any application-specific
# dependencies here.
target_link_libraries(${BINARY_NAME} PRIVATE flutter flutter_wrapper_app)
target_link_libraries(${BINARY_NAME} PRIVATE "dwmapi.lib")
target_link_libraries(${BINARY_NAME} PRIVATE windowsapp advapi32 wintrust crypt32)
target_link_libraries(${BINARY_NAME} PRIVATE shell32 propsys)
add_executable(revisit_notification_setup "notification_setup.cpp" "notification_identity.cpp")
apply_standard_settings(revisit_notification_setup)
target_link_libraries(revisit_notification_setup PRIVATE shell32 propsys ole32 windowsapp advapi32)
add_dependencies(${BINARY_NAME} revisit_notification_setup)
add_executable(revisit_desktop_host
  "../../companion/windows_host/desktop_host.cpp"
  "../../companion/windows_host/protocol.cpp"
  "../../companion/windows_host/pipe_transport.cpp"
  "../../companion/windows_host/peer_identity.cpp")
apply_standard_settings(revisit_desktop_host)
target_compile_definitions(revisit_desktop_host PRIVATE UNICODE _UNICODE WIN32_LEAN_AND_MEAN NOMINMAX)
target_link_libraries(revisit_desktop_host PRIVATE advapi32 wintrust crypt32)
add_dependencies(${BINARY_NAME} revisit_desktop_host)
target_include_directories(${BINARY_NAME} PRIVATE "${CMAKE_SOURCE_DIR}")

# Run the Flutter tool portions of the build. This must not be removed.
add_dependencies(${BINARY_NAME} flutter_assemble)
