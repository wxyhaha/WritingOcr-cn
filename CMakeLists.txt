cmake_minimum_required(VERSION 3.20)

project(HandwritingOCR VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOUIC ON)

find_package(Qt6 6.5 REQUIRED COMPONENTS
    Core
    Gui
    Qml
    Quick
    QuickControls2
    Sql
    Network
    Concurrent
)

# Source files
set(SOURCES
    app/main.cpp
    app/AppController.cpp
    app/AppController.h
    
    # Models
    app/models/Task.h
    app/models/Page.h
    app/models/OcrResult.h
    app/models/OcrBlock.h
    app/models/TaskListModel.cpp
    app/models/TaskListModel.h
    app/models/PageListModel.cpp
    app/models/PageListModel.h
    app/models/OcrBlockListModel.cpp
    app/models/OcrBlockListModel.h

    # Infrastructure
    app/infrastructure/logging/Logger.cpp
    app/infrastructure/logging/Logger.h
    app/infrastructure/database/DatabaseManager.cpp
    app/infrastructure/database/DatabaseManager.h
    app/infrastructure/network/QrCodeGenerator.cpp
    app/infrastructure/network/QrCodeGenerator.h
    app/infrastructure/network/LanHttpServer.cpp
    app/infrastructure/network/LanHttpServer.h
    app/infrastructure/ocr/IOcrProvider.h
    app/infrastructure/ocr/PaddleOcrProvider.cpp
    app/infrastructure/ocr/PaddleOcrProvider.h
    app/infrastructure/export/IExporter.h
    app/infrastructure/export/TxtExporter.cpp
    app/infrastructure/export/TxtExporter.h
    app/infrastructure/export/MarkdownExporter.cpp
    app/infrastructure/export/MarkdownExporter.h
    app/infrastructure/export/DocxExporter.cpp
    app/infrastructure/export/DocxExporter.h
    app/infrastructure/utils/PathUtils.h

    # Services
    app/services/StorageService.cpp
    app/services/StorageService.h
    app/services/SettingsService.cpp
    app/services/SettingsService.h
    app/services/TaskService.cpp
    app/services/TaskService.h
    app/services/ImageService.cpp
    app/services/ImageService.h
    app/services/LanUploadService.cpp
    app/services/LanUploadService.h
    app/services/OcrService.cpp
    app/services/OcrService.h
    app/services/ExportService.cpp
    app/services/ExportService.h

    # QRC
    app/qml.qrc
)

add_executable(HandwritingOCR ${SOURCES})

target_link_libraries(HandwritingOCR PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Qml
    Qt6::Quick
    Qt6::QuickControls2
    Qt6::Sql
    Qt6::Network
    Qt6::Concurrent
)

# Test executables
enable_testing()

add_executable(test_storage_db
    tests/test_storage_db.cpp
    app/infrastructure/database/DatabaseManager.cpp
    app/infrastructure/logging/Logger.cpp
    app/services/StorageService.cpp
    app/models/TaskListModel.cpp
    app/models/PageListModel.cpp
    app/models/OcrBlockListModel.cpp
)
target_link_libraries(test_storage_db PRIVATE Qt6::Core Qt6::Sql)
add_test(NAME test_storage_db COMMAND test_storage_db)

add_executable(test_exporters
    tests/test_exporters.cpp
    app/infrastructure/export/TxtExporter.cpp
    app/infrastructure/export/MarkdownExporter.cpp
    app/infrastructure/export/DocxExporter.cpp
    app/infrastructure/logging/Logger.cpp
)
target_link_libraries(test_exporters PRIVATE Qt6::Core)
add_test(NAME test_exporters COMMAND test_exporters)


# Copy web-upload, ocr-worker and scripts directories to output build directory
add_custom_command(TARGET HandwritingOCR POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_directory
        "${CMAKE_CURRENT_SOURCE_DIR}/web-upload"
        "$<TARGET_FILE_DIR:HandwritingOCR>/web-upload"
    COMMAND ${CMAKE_COMMAND} -E copy_directory
        "${CMAKE_CURRENT_SOURCE_DIR}/ocr-worker"
        "$<TARGET_FILE_DIR:HandwritingOCR>/ocr-worker"
    COMMAND ${CMAKE_COMMAND} -E copy_directory
        "${CMAKE_CURRENT_SOURCE_DIR}/scripts"
        "$<TARGET_FILE_DIR:HandwritingOCR>/scripts"
)
