@echo off
set args=%*
rem Tree-sitter passes Rust's MSVC target; Zig's bundled MinGW target avoids a Windows SDK dependency.
set args=%args:x86_64-pc-windows-msvc=x86_64-windows-gnu%
zig cc %args%
exit /b %ERRORLEVEL%
