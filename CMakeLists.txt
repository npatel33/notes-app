project(com.ubuntu.reminders C CXX)
cmake_minimum_required(VERSION 2.8.9)
find_program(INTLTOOL_MERGE intltool-merge)
find_program(INTLTOOL_EXTRACT intltool-extract)

set(CMAKE_AUTOMOC ON)
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -std=c++11 -fno-permissive -pedantic -Wall -Wextra -fPIC")

include(FindPkgConfig)
# Standard install paths
include(GNUInstallDirs)

option(INSTALL_TESTS "Install the tests on make install" on)
option(CLICK_MODE "Installs to a contained location" on)
option(USE_XVFB "Use XVFB to run qml tests" on)

enable_testing()

set(APP_NAME reminders)
set(DESKTOP_FILE "${PROJECT_NAME}.desktop")
set(APPLICATION_FILE "${PROJECT_NAME}_${APP_NAME}.application")
set(ICON ${APP_NAME}.png)
set(AUTOPILOT_DIR reminders)
set(APP_HARDCODE reminders)
set(LP_PROJECT reminders-app)
set(MAIN_QML ${APP_HARDCODE}.qml)
set(EXEC "reminders %u")
set(UBUNTU_MANIFEST_PATH "manifest.json.in" CACHE INTERNAL "Relative path to the manifest file")

set(ACCOUNT_ICON_DIR ${CMAKE_INSTALL_DATADIR}/icons/hicolor/32x32/apps)
set(ACCOUNT_PROVIDER_DIR ${CMAKE_INSTALL_DATADIR}/accounts/providers)
set(ACCOUNT_SERVICE_DIR ${CMAKE_INSTALL_DATADIR}/accounts/services)
set(ACCOUNT_QML_PLUGIN_DIR ${CMAKE_INSTALL_DATADIR}/accounts/qml-plugins)

if(CLICK_MODE)
    if(NOT DEFINED BZR_SOURCE)
        set(BZR_SOURCE "lp:${LP_PROJECT}")
        message("-- Setting BZR_SOURCE to ${BZR_SOURCE}")
    endif(NOT DEFINED BZR_SOURCE)
    execute_process(
        COMMAND dpkg-architecture -qDEB_HOST_MULTIARCH
            OUTPUT_VARIABLE ARCH_TRIPLET
            OUTPUT_STRIP_TRAILING_WHITESPACE
    )
    set(CMAKE_INSTALL_PREFIX /)
    set(QT_IMPORTS_DIR "/lib/${ARCH_TRIPLET}")
    set(BIN_DIR /lib/${ARCH_TRIPLET}/bin)
    set(DATA_DIR /)
    set(DESKTOP_DIR ${DATA_DIR})
    set(APPLICATION_DIR ${DATA_DIR})

    if(NOT BZR_REVNO)
      execute_process(
        COMMAND bzr revno
                OUTPUT_VARIABLE BZR_REVNO
                WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
                OUTPUT_STRIP_TRAILING_WHITESPACE
      )
    endif(NOT BZR_REVNO)

    execute_process(
      COMMAND dpkg-architecture -qDEB_HOST_ARCH
      OUTPUT_VARIABLE CLICK_ARCH
      OUTPUT_STRIP_TRAILING_WHITESPACE
    )
    configure_file(manifest.json.in ${CMAKE_CURRENT_BINARY_DIR}/manifest.json)

    # make the click files visible in qtcreator
    file(GLOB CLICK_FILES
         RELATIVE ${CMAKE_CURRENT_SOURCE_DIR}
         *.json *.json.in *.apparmor)

    add_custom_target(com_ubuntu_reminders_CLICKFiles ALL SOURCES ${CLICK_FILES})

    install(FILES ${CMAKE_CURRENT_BINARY_DIR}/manifest.json
        reminders.apparmor
        reminders.url-dispatcher
        push-helper.json
        push-helper.apparmor
        reminders-contenthub.json
        DESTINATION ${CMAKE_INSTALL_PREFIX})
install(FILES COPYING DESTINATION ${CMAKE_INSTALL_PREFIX})
else(CLICK_MODE)
    # components PATH
    set(QT_IMPORTS_DIR "${CMAKE_INSTALL_LIBDIR}/qt5/qml")
    set(DATA_DIR ${CMAKE_INSTALL_DATADIR}/${APP_HARDCODE})
    set(ICON "${CMAKE_INSTALL_PREFIX}/${DATA_DIR}/${ICON}")
    set(DESKTOP_DIR ${CMAKE_INSTALL_DATADIR}/applications)
    set(APPLICATION_DIR ${CMAKE_INSTALL_DATADIR}/accounts/applications)
endif(CLICK_MODE)

file(GLOB_RECURSE I18N_SRC_FILES
    RELATIVE ${CMAKE_CURRENT_SOURCE_DIR}
    *.qml *.js *.cpp *.h)
list(APPEND I18N_SRC_FILES ${DESKTOP_FILE}.in.in.h)
list(SORT I18N_SRC_FILES)

file(GLOB SRC_FILES
    RELATIVE ${CMAKE_CURRENT_SOURCE_DIR}
    *.qml *.js *.png *.js)
install(FILES ${SRC_FILES}  DESTINATION ${DATA_DIR})

configure_file(${DESKTOP_FILE}.in.in ${CMAKE_CURRENT_BINARY_DIR}/${DESKTOP_FILE}.in)

add_custom_target(${DESKTOP_FILE} ALL
    COMMENT "Merging translations into ${DESKTOP_FILE}"
    COMMAND LC_ALL=C ${INTLTOOL_MERGE} -d -u ${CMAKE_SOURCE_DIR}/po ${DESKTOP_FILE}.in ${DESKTOP_FILE} > /dev/null
)
install(FILES ${CMAKE_CURRENT_BINARY_DIR}/${DESKTOP_FILE} DESTINATION ${DESKTOP_DIR})

configure_file(${APPLICATION_FILE}.in ${CMAKE_CURRENT_BINARY_DIR}/${APPLICATION_FILE})
install(FILES ${CMAKE_CURRENT_BINARY_DIR}/${APPLICATION_FILE} DESTINATION ${APPLICATION_DIR})

add_subdirectory(po)
add_subdirectory(tests)
add_subdirectory(3rdParty)
add_subdirectory(src)
