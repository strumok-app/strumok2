#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  HANDLE instance_mutex =
      ::CreateMutexW(nullptr, TRUE, L"Local\\app.strumok.SingleInstance");
  if (instance_mutex == nullptr) {
    ::OutputDebugStringW(
        L"Strumok: Failed to create the single-instance mutex.\n");
    return EXIT_FAILURE;
  }
  if (::GetLastError() == ERROR_ALREADY_EXISTS) {
    HWND existing_window =
        ::FindWindowW(L"FLUTTER_RUNNER_WIN32_WINDOW", L"Strumok");
    if (existing_window != nullptr) {
      if (::IsIconic(existing_window)) {
        ::ShowWindow(existing_window, SW_RESTORE);
      }
      ::SetForegroundWindow(existing_window);
    }
    ::CloseHandle(instance_mutex);
    return EXIT_SUCCESS;
  }

  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Size size(1280, 720);
  RECT work_area;
  ::SystemParametersInfo(SPI_GETWORKAREA, 0, &work_area, 0);
  const double scale = ::GetDpiForSystem() / 96.0;
  const int free_x = static_cast<int>((work_area.right - work_area.left) / scale) - 1280;
  const int free_y = static_cast<int>((work_area.bottom - work_area.top) / scale) - 720;
  Win32Window::Point origin(free_x > 0 ? free_x / 2 : 0, free_y > 0 ? free_y / 2 : 0);
  if (!window.Create(L"Strumok", origin, size)) {
    ::ReleaseMutex(instance_mutex);
    ::CloseHandle(instance_mutex);
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  ::ReleaseMutex(instance_mutex);
  ::CloseHandle(instance_mutex);
  return EXIT_SUCCESS;
}
