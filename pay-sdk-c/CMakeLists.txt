cmake_minimum_required(VERSION 3.15)
project(pay-sdk-c VERSION 1.0.0 LANGUAGES C CXX)

set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)
set(CMAKE_CXX_STANDARD 14)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# ==========================================================================
#  Library target
# ==========================================================================
add_library(pay_sdk STATIC
    src/sha256.c
    src/hmac.c
    src/aes.c
    src/base64.c
    src/json.c
    src/http.c
    src/pay.c
)

target_include_directories(pay_sdk PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}/include
)

# Platform-specific linking
if(WIN32)
    target_link_libraries(pay_sdk PUBLIC winhttp ws2_32)
    target_compile_definitions(pay_sdk PRIVATE -D_CRT_SECURE_NO_WARNINGS)
else()
    find_package(CURL REQUIRED)
    target_link_libraries(pay_sdk PUBLIC CURL::libcurl)
endif()

# ==========================================================================
#  Tests
# ==========================================================================
option(PAY_BUILD_TESTS "Build test programs" ON)

if(PAY_BUILD_TESTS)
    # C test
    add_executable(test_pay_c tests/test_pay.c)
    target_link_libraries(test_pay_c PRIVATE pay_sdk)
    target_include_directories(test_pay_c PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/src)

    # C++ test
    add_executable(test_pay_cpp tests/test_pay.cpp)
    target_link_libraries(test_pay_cpp PRIVATE pay_sdk)

    # Enable testing
    enable_testing()
    add_test(NAME test_pay_c     COMMAND test_pay_c)
    add_test(NAME test_pay_cpp   COMMAND test_pay_cpp)
endif()

# ==========================================================================
#  Install (optional)
# ==========================================================================
include(GNUInstallDirs)
install(TARGETS pay_sdk
    ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
)
install(DIRECTORY include/
    DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}
)
