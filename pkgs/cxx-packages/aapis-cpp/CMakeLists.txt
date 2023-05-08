cmake_minimum_required(VERSION 3.16)
project(aapis-cpp LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 20)

include(GNUInstallDirs)
include(include.cmake)
include(src.cmake)

add_library(aapis-cpp SHARED ${sources} ${headers})
target_include_directories(aapis-cpp PUBLIC protos)
target_link_libraries(aapis-cpp protobuf)

install(TARGETS aapis-cpp LIBRARY)
foreach(header ${headers})
    string(REGEX REPLACE "(\.\/)*protos\/(.*)" "include/\\2" destFile ${header})
    get_filename_component(dest ${destFile} DIRECTORY)
    install(FILES ${header} DESTINATION ${dest})
endforeach()

if(DEFINED ENV{out})
    install(TARGETS aapis-cpp LIBRARY DESTINATION $ENV{out}/lib)
endif()
