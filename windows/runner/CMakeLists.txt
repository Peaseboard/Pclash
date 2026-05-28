cmake_minimum_required(VERSION 3.14)
project(pclash LANGUAGES CXX)

set(BINARY_NAME "pclash")

cmake_policy(SET CMP0063 NEW)

set(CMAKE_INSTALL_RPATH "$ORIGIN/lib")

# Configure build options.
get_filename_component(PARENT_DIR "${CMAKE_CURRENT_SOURCE_DIR}" DIRECTORY)
get_filename_component(FLUTTER_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/../.." ABSOLUTE)

# Include the CMakeLists from Flutter
include("${FLUTTER_ROOT}/packages/flutter_tools/gradle/src/main/groovy/CMakeLists.txt" OPTIONAL)

# Application configuration
set(ICON_PATH "${CMAKE_CURRENT_SOURCE_DIR}/runner/resources/app_icon.ico")

# Source files
set(RUNNER_SOURCES
  "flutter_window.cpp"
  "main.cpp"
  "proxy_plugin.cpp"
  "utils.cpp"
  "win32_window.cpp"
  "${FLUTTER_MANAGED_DIR}/generated_plugin_registrant.cc"
  "Runner.rc"
  "runner.exe.manifest"
)

# Define the target executable
add_executable(${BINARY_NAME} WIN32
  ${RUNNER_SOURCES}
)

# Apply standard C++ settings
target_compile_definitions(${BINARY_NAME} PRIVATE "NOMINMAX")
target_link_libraries(${BINARY_NAME} PRIVATE flutter flutter_wrapper_app)
target_link_libraries(${BINARY_NAME} PRIVATE
  "dwmapi.lib"
  "wininet.lib"  # For InternetSetOption
)
target_include_directories(${BINARY_NAME} PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}")

# Link to Windows App SDK if available
if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/windowsappsdk.cmake")
  include("${CMAKE_CURRENT_SOURCE_DIR}/windowsappsdk.cmake")
endif()

# Install rules
install(TARGETS ${BINARY_NAME} RUNTIME DESTINATION "${CMAKE_INSTALL_PREFIX}" COMPONENT Runtime)
