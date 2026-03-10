-- RmlUi xmake build script
-- Replaces the CMake build system

set_project("RmlUi")
set_version("6.3", {build = "$(buildversion)"})

add_rules("plugin.compile_commands.autoupdate", {outputdir = "build"})
add_rules("mode.releasedbg")

-- C++17 required
set_languages("cxx17")
set_encodings("utf-8")

-- Options
option("shared",      {description = "Build shared libraries", default = false})
option("samples",     {description = "Build samples", default = false})
option("font_engine", {description = "Font engine: freetype or none", default = "freetype", values = {"freetype", "none"}})
option("lua",         {description = "Build Lua bindings", default = false})
option("lua_lib",     {description = "Lua library: lua, lua_as_cxx, luajit", default = "lua", values = {"lua", "lua_as_cxx", "luajit"}})
option("lottie",      {description = "Enable Lottie plugin (requires rlottie)", default = false})
option("svg",         {description = "Enable SVG plugin (requires lunasvg)", default = false})
option("harfbuzz",    {description = "Enable HarfBuzz sample (requires harfbuzz)", default = false})
option("thirdparty_containers", {description = "Use integrated third-party containers", default = true})
option("matrix_row_major",      {description = "Use row-major matrices", default = false})
option("custom_rtti",           {description = "Use custom RTTI implementation", default = false})
option("tracy",                 {description = "Enable Tracy profiling", default = false})
option("tracy_memory",          {description = "Track memory allocations in Tracy", default = true})
option("tests",                 {description = "Build tests", default = false})
option("backend",               {description = "Backend: auto, SDL_GL2, SDL_GL3, SDL_SDLrenderer, SDL_GPU, SDL_VK, GLFW_GL2, GLFW_GL3, GLFW_VK, Win32_GL2, Win32_VK, X11_GL2, SFML_GL2", default = "auto"})
option("backend_simulate_touch",{description = "Simulate touch events with mouse events", default = false})

add_requires("freetype")
add_requires("libsdl3", "libsdl3_image")
add_requires("glfw", "opengl", "sfml")

function is_toolchain(...)
    local t = get_config("toolchain")
    for _, v in ipairs({...}) do
        if t == v then return true end
    end
    return false
end

-- Helper: resolve backend automatically
function get_resolved_backend()
    local backend = get_config("backend")
    if backend ~= "auto" then
        return backend
    end
    if is_plat("windows") then
        return "GLFW_GL3"
    elseif is_plat("macosx") then
        return "SDL_SDLrenderer"
    else
        return "GLFW_GL3"
    end
end

-- ============================================================
-- rmlui_core
-- ============================================================
target("rmlui_core")
    if has_config("shared") then
        set_kind("shared")
    else
        set_kind("static")
    end

    set_basename("rmlui")

    add_includedirs("Include", {public = true})

    -- Version string
    add_defines('RMLUI_VERSION="6.3-dev"')

    -- Export/import macros
    if has_config("shared") then
        add_defines("RMLUI_CORE_EXPORTS")
    else
        add_defines("RMLUI_STATIC_LIB", {public = true})
    end

    -- Optional compile definitions (public, inherited by consumers)
    if not has_config("thirdparty_containers") then
        add_defines("RMLUI_NO_THIRDPARTY_CONTAINERS", {public = true})
    end
    if has_config("custom_rtti") then
        add_defines("RMLUI_CUSTOM_RTTI", {public = true})
    end
    if has_config("matrix_row_major") then
        add_defines("RMLUI_MATRIX_ROW_MAJOR", {public = true})
    end

    -- Core source files
    add_files("Source/Core/*.cpp")

    -- Elements sub-directory sources
    add_files("Source/Core/Elements/**.cpp")

    -- Layout sub-directory sources
    add_files("Source/Core/Layout/**.cpp")

    -- FreeType font engine
    if has_config("font_engine") and get_config("font_engine") == "freetype" then
        add_files("Source/Core/FontEngineDefault/**.cpp")
        add_defines("RMLUI_FONT_ENGINE_FREETYPE")
        add_packages("freetype", {public = false})
    end

    -- Lottie plugin
    if has_config("lottie") then
        add_files(
            "Source/Lottie/*.cpp"
        )
        add_defines("RMLUI_LOTTIE_PLUGIN")
        add_packages("rlottie")
    end

    -- SVG plugin
    if has_config("svg") then
        add_files("Source/SVG/**.cpp")

        add_defines("RMLUI_SVG_PLUGIN")
        add_packages("lunasvg")
    end

    -- Tracy profiling
    if has_config("tracy") then
        add_defines("RMLUI_TRACY_PROFILING", {public = true})
        if has_config("tracy_memory") then
            add_defines("RMLUI_TRACY_MEMORY_PROFILING")
        end
        add_packages("tracy")
    end

    -- Compiler warnings
    if get_config("toolchain") == "clang" or get_config("toolchain") == "gcc" then
        add_cxxflags("-Wall", "-Wextra", "-pedantic")
    elseif get_config("toolchain") == "msvc" then
        add_cxxflags("/W4", "/w44062", "/permissive-")
        add_defines("_CRT_SECURE_NO_WARNINGS")
    end

-- ============================================================
-- rmlui_debugger
-- ============================================================
target("rmlui_debugger")
    if has_config("shared") then
        set_kind("shared")
    else
        set_kind("static")
    end

    add_includedirs("Include", {public = true})
    add_deps("rmlui_core", {public = true})

    if has_config("shared") then
        add_defines("RMLUI_DEBUGGER_EXPORTS")
    end

    add_files("Source/Debugger/**.cpp")

    if get_config("toolchain") == "clang" or get_config("toolchain") == "gcc" then
        add_cxxflags("-Wall", "-Wextra", "-pedantic")
    elseif get_config("toolchain") == "msvc" then
        add_cxxflags("/W4", "/w44062", "/permissive-")
        add_defines("_CRT_SECURE_NO_WARNINGS")
    end

-- ============================================================
-- rmlui_lua (optional)
-- ============================================================
if has_config("lua") then
    target("rmlui_lua")
        if has_config("shared") then
            set_kind("shared")
        else
            set_kind("static")
        end

        add_includedirs("Include", {public = true})
        add_deps("rmlui_core", {public = true})

        if has_config("shared") then
            add_defines("RMLUI_LUA_EXPORTS")
        end

        if get_config("lua_lib") == "lua_as_cxx" then
            add_defines("RMLUI_LUA_AS_CXX", {public = true})
        end

        add_files("Source/Lua/**.cpp")

        if get_config("lua_lib") == "luajit" then
            add_packages("luajit", {public = true})
        else
            add_packages("lua", {public = true})
        end

        if is_toolchain("clang", "gcc") then
            add_cxxflags("-Wall", "-Wextra", "-pedantic")
        elseif is_toolchain("msvc") then
            add_cxxflags("/W4", "/w44062", "/permissive-")
            add_defines("_CRT_SECURE_NO_WARNINGS")
        end
end

-- ============================================================
-- Samples & Shell
-- ============================================================
if has_config("samples") then

    -- Helper: resolved backend
    local _backend = nil
    function resolved_backend()
        if _backend then return _backend end
        local b = get_config("backend")
        if b == "auto" or b == nil or b == "" then
            if is_plat("windows") then
                b = "GLFW_GL3"
            elseif is_plat("macosx") then
                b = "SDL_SDLrenderer"
            else
                b = "GLFW_GL3"
            end
        end
        _backend = b
        return b
    end

    -- --------------------------------------------------------
    -- rmlui_shell (static utility library for samples)
    -- --------------------------------------------------------
    target("rmlui_shell")
        set_kind("static")
        add_includedirs("Samples/shell/include", {public = true})
        add_includedirs("Backends", {public = true})
        add_deps("rmlui_core", {public = true})
        add_deps("rmlui_debugger", {public = true})

        add_files("Samples/shell/src/*.cpp")

        -- Backend source files (compiled into shell)
        -- Common backend header include
        add_includedirs("Backends")

        -- Add backend-specific source files based on selected backend
        -- We use on_config to resolve at configuration time
        on_config(function(target)
            local backend = target:extraconf("backend") or get_config("backend") or "auto"
            if backend == "auto" or backend == "native" then
                if is_plat("windows") then
                    backend = "GLFW_GL3"
                elseif is_plat("macosx") then
                    backend = "SDL_SDLrenderer"
                else
                    backend = "GLFW_GL3"
                end
            end

            local backends_dir = "$(projectdir)/Backends"

            -- Common platform files
            local files = {}
            if backend:find("Win32") then
                table.insert(files, backends_dir .. "/RmlUi_Platform_Win32.cpp")
            elseif backend:find("SDL") then
                table.insert(files, backends_dir .. "/RmlUi_Platform_SDL.cpp")
            elseif backend:find("GLFW") then
                table.insert(files, backends_dir .. "/RmlUi_Platform_GLFW.cpp")
            elseif backend:find("SFML") then
                table.insert(files, backends_dir .. "/RmlUi_Platform_SFML.cpp")
            elseif backend:find("X11") then
                table.insert(files, backends_dir .. "/RmlUi_Platform_X11.cpp")
            end

            -- Renderer files
            if backend:find("GL2") then
                table.insert(files, backends_dir .. "/RmlUi_Renderer_GL2.cpp")
                target:add("defines", "RMLUI_RENDERER_GL2")
            elseif backend:find("GL3") then
                table.insert(files, backends_dir .. "/RmlUi_Renderer_GL3.cpp")
                target:add("defines", "RMLUI_RENDERER_GL3")
            elseif backend:find("VK") then
                table.insert(files, backends_dir .. "/RmlUi_Renderer_VK.cpp")
            elseif backend == "SDL_SDLrenderer" then
                table.insert(files, backends_dir .. "/RmlUi_Renderer_SDL.cpp")
            elseif backend == "SDL_GPU" then
                table.insert(files, backends_dir .. "/RmlUi_Renderer_SDL_GPU.cpp")
            end

            -- Backend glue file
            table.insert(files, backends_dir .. "/RmlUi_Backend_" .. backend .. ".cpp")

            for _, f in ipairs(files) do
                target:add("files", f)
            end

            -- SDL version define (required by SDL backend headers)
            if backend:find("SDL") then
                target:add("defines", "RMLUI_SDL_VERSION_MAJOR=3")
            end

            -- simulate touch
            if get_config("backend_simulate_touch") and backend:find("SDL") then
                target:add("defines", "RMLUI_BACKEND_SIMULATE_TOUCH")
            end
        end)

        -- Platform libs
        if is_plat("windows") then
            add_syslinks("Shlwapi")
        elseif is_plat("macosx") then
            add_frameworks("Cocoa")
        end

        -- Backend dependencies (packages)
        on_load(function(target)
            local backend = get_config("backend") or "auto"
            if backend == "auto" or backend == "native" then
                if is_plat("windows") then
                    backend = "GLFW_GL3"
                elseif is_plat("macosx") then
                    backend = "SDL_SDLrenderer"
                else
                    backend = "GLFW_GL3"
                end
            end

            if backend:find("SDL") then
                target:add("packages", "libsdl3")
                target:add("packages", "libsdl3_image")
            end
            if backend:find("GLFW") then
                target:add("packages", "glfw")
                target:add("packages", "opengl")
            end
            if backend:find("SFML") then
                target:add("packages", "sfml")
            end
            if backend == "GL2" or backend:find("GL2") then
                target:add("packages", "opengl")
            end
            if backend:find("X11") then
                target:add("packages", "libx11")
                target:add("packages", "opengl")
            end
            if is_plat("linux") and (backend:find("GL3") or backend:find("VK")) then
                target:add("syslinks", "dl")
            end
        end)

        if get_config("toolchain") == "clang" or get_config("toolchain") == "gcc" then
            add_cxxflags("-Wall", "-Wextra", "-pedantic")
        elseif get_config("toolchain") == "msvc" then
            add_cxxflags("/W4", "/w44062", "/permissive-")
            add_defines("_CRT_SECURE_NO_WARNINGS")
        end

    -- --------------------------------------------------------
    -- Helper function to define a sample target
    -- --------------------------------------------------------
    function add_sample(name, srcdir)
        target("rmlui_sample_" .. name)
            set_kind("binary")
            add_deps("rmlui_shell")
            add_files((srcdir or ("Samples/basic/" .. name .. "/src")) .. "/*.cpp")
            if is_plat("windows") then
                add_ldflags("/SUBSYSTEM:WINDOWS", {force = true})
            end
    end

    -- bitmap_font (no font engine required)
    add_sample("bitmap_font")

    -- Samples requiring font engine
    if get_config("font_engine") ~= "none" then
        add_sample("animation")
        add_sample("benchmark")
        add_sample("custom_log")
        add_sample("data_binding")

        -- demo (needs /utf-8 on MSVC)
        target("rmlui_sample_demo")
            set_kind("binary")
            add_deps("rmlui_shell")
            add_files("Samples/basic/demo/src/*.cpp")
            if is_plat("windows") then
                add_ldflags("/SUBSYSTEM:WINDOWS", {force = true})
            end
            if get_config("toolchain") == "msvc" then
                add_cxxflags("/utf-8")
            end

        add_sample("drag")
        add_sample("load_document")
        add_sample("transform")
        add_sample("tree_view")

        -- effects (GL3 only - check backend at config time)
        local _b = get_config("backend") or "auto"
        if _b == "auto" then
            if is_plat("windows") then _b = "GLFW_GL3"
            elseif is_plat("macosx") then _b = "SDL_SDLrenderer"
            else _b = "GLFW_GL3" end
        end
        if _b:find("GL3") then
            add_sample("effects")
        end

        -- harfbuzz sample
        if has_config("harfbuzz") then
            target("rmlui_sample_harfbuzz")
                set_kind("binary")
                add_deps("rmlui_shell")
                add_includedirs("Source/Core")
                add_files("Samples/basic/harfbuzz/src/*.cpp")
                add_packages("freetype", "harfbuzz")
                if is_plat("windows") then
                    add_ldflags("/SUBSYSTEM:WINDOWS", {force = true})
                end
        end

        -- lottie sample
        if has_config("lottie") then
            add_sample("lottie")
        end

        -- svg sample
        if has_config("svg") then
            add_sample("svg")
        end

        -- ime sample (Win32 only)
        if is_plat("windows") then
            local backend = get_config("backend") or "auto"
            if backend == "auto" then backend = "GLFW_GL3" end
            if backend:find("Win32") then
                add_sample("ime")
            end
        end

        -- invaders
        add_sample("invaders", "Samples/invaders/src")

        -- tutorials
        target("rmlui_tutorial_drag")
            set_kind("binary")
            add_deps("rmlui_shell")
            add_files("Samples/tutorial/drag/src/*.cpp")
            if is_plat("windows") then
                add_ldflags("/SUBSYSTEM:WINDOWS", {force = true})
            end

        target("rmlui_tutorial_template")
            set_kind("binary")
            add_deps("rmlui_shell")
            add_files("Samples/tutorial/template/src/*.cpp")
            if is_plat("windows") then
                add_ldflags("/SUBSYSTEM:WINDOWS", {force = true})
            end

        -- lua_invaders (requires Lua bindings)
        if has_config("lua") then
            target("rmlui_sample_lua_invaders")
                set_kind("binary")
                add_deps("rmlui_shell", "rmlui_lua")
                add_files("Samples/lua_invaders/src/*.cpp")
                if get_config("lua_lib") == "luajit" then
                    add_packages("luajit")
                else
                    add_packages("lua")
                end
                if is_plat("windows") then
                    add_ldflags("/SUBSYSTEM:WINDOWS", {force = true})
                end
        end
    end -- font_engine != none
end -- samples

-- ============================================================
-- Tests
-- ============================================================
if has_config("tests") then

    -- Enable test code in core
    target("rmlui_core")
        add_defines("RMLUI_TESTS_ENABLED", {public = true})

    -- rmlui_tests_common (static helper library)
    target("rmlui_tests_common")
        set_kind("static")
        add_includedirs("Tests/Source/Common", {public = true})
        add_deps("rmlui_core", {public = true})
        add_deps("rmlui_shell", {public = true})
        add_deps("rmlui_debugger", {public = true})

        add_includedirs("Tests/Dependencies/doctest", {public = true})
        add_includedirs("Tests/Dependencies/trompeloeil", {public = true})

        add_files(
            "Tests/Source/Common/TestsInterface.cpp",
            "Tests/Source/Common/TestsShell.cpp"
        )

        if is_toolchain("msvc") then
            add_defines("DOCTEST_CONFIG_USE_STD_HEADERS")
        end

        if is_toolchain("clang", "gcc") then
            add_cxxflags("-Wall", "-Wextra", "-pedantic")
        elseif is_toolchain("msvc") then
            add_cxxflags("/W4", "/w44062", "/permissive-")
            add_defines("_CRT_SECURE_NO_WARNINGS")
        end

    -- rmlui_benchmarks
    target("rmlui_benchmarks")
        set_kind("binary")
        add_deps("rmlui_tests_common", "rmlui_core")
        add_includedirs("Tests/Dependencies/doctest")
        add_includedirs("Tests/Dependencies/nanobench")

        add_files(
            "Tests/Source/Benchmarks/DataExpression.cpp",
            "Tests/Source/Benchmarks/Element.cpp",
            "Tests/Source/Benchmarks/BackgroundBorder.cpp",
            "Tests/Source/Benchmarks/ElementDocument.cpp",
            "Tests/Source/Benchmarks/Table.cpp",
            "Tests/Source/Benchmarks/Selectors.cpp",
            "Tests/Source/Benchmarks/main.cpp",
            "Tests/Source/Benchmarks/DataBinding.cpp",
            "Tests/Source/Benchmarks/Flexbox.cpp",
            "Tests/Source/Benchmarks/FontEffect.cpp",
            "Tests/Source/Benchmarks/WidgetTextInput.cpp"
        )

        if is_toolchain("msvc") then
            add_cxxflags("/utf-8")
            add_cxxflags("/W4", "/w44062", "/permissive-")
            add_defines("_CRT_SECURE_NO_WARNINGS")
        elseif is_toolchain("clang", "gcc") then
            add_cxxflags("-Wall", "-Wextra", "-pedantic")
        end

    -- rmlui_unit_tests
    target("rmlui_unit_tests")
        set_kind("binary")
        add_deps("rmlui_tests_common", "rmlui_core")
        add_includedirs("Tests/Dependencies/doctest")
        add_includedirs("Tests/Dependencies/trompeloeil")

        add_files(
            "Tests/Source/UnitTests/Animation.cpp",
            "Tests/Source/UnitTests/Core.cpp",
            "Tests/Source/UnitTests/DataBinding.cpp",
            "Tests/Source/UnitTests/DataExpression.cpp",
            "Tests/Source/UnitTests/DataModel.cpp",
            "Tests/Source/UnitTests/Debugger.cpp",
            "Tests/Source/UnitTests/Decorator.cpp",
            "Tests/Source/UnitTests/Element.cpp",
            "Tests/Source/UnitTests/ElementBackgroundBorder.cpp",
            "Tests/Source/UnitTests/ElementDocument.cpp",
            "Tests/Source/UnitTests/ElementHandle.cpp",
            "Tests/Source/UnitTests/ElementFormControlSelect.cpp",
            "Tests/Source/UnitTests/ElementImage.cpp",
            "Tests/Source/UnitTests/ElementStyle.cpp",
            "Tests/Source/UnitTests/EventListener.cpp",
            "Tests/Source/UnitTests/Filter.cpp",
            "Tests/Source/UnitTests/FlexFormatting.cpp",
            "Tests/Source/UnitTests/Layout.cpp",
            "Tests/Source/UnitTests/Localization.cpp",
            "Tests/Source/UnitTests/main.cpp",
            "Tests/Source/UnitTests/Math.cpp",
            "Tests/Source/UnitTests/MediaQuery.cpp",
            "Tests/Source/UnitTests/Properties.cpp",
            "Tests/Source/UnitTests/PropertySpecification.cpp",
            "Tests/Source/UnitTests/Selectors.cpp",
            "Tests/Source/UnitTests/Specificity_Basic.cpp",
            "Tests/Source/UnitTests/Specificity_MediaQuery.cpp",
            "Tests/Source/UnitTests/StableVector.cpp",
            "Tests/Source/UnitTests/StringUtilities.cpp",
            "Tests/Source/UnitTests/StyleSheetParser.cpp",
            "Tests/Source/UnitTests/Template.cpp",
            "Tests/Source/UnitTests/URL.cpp",
            "Tests/Source/UnitTests/Variant.cpp",
            "Tests/Source/UnitTests/XMLParser.cpp"
        )

        if is_toolchain("clang", "gcc") then
            add_cxxflags("-Wall", "-Wextra", "-pedantic")
        elseif is_toolchain("msvc") then
            add_cxxflags("/W4", "/w44062", "/permissive-")
            add_defines("_CRT_SECURE_NO_WARNINGS")
        end

    -- rmlui_visual_tests
    target("rmlui_visual_tests")
        set_kind("binary")
        add_deps("rmlui_tests_common", "rmlui_core", "rmlui_shell")
        add_includedirs("Tests/Dependencies/doctest")
        add_includedirs("Tests/Dependencies/lodepng")

        add_files(
            "Tests/Source/VisualTests/XmlNodeHandlers.cpp",
            "Tests/Source/VisualTests/TestViewer.cpp",
            "Tests/Source/VisualTests/TestConfig.cpp",
            "Tests/Source/VisualTests/TestNavigator.cpp",
            "Tests/Source/VisualTests/main.cpp",
            "Tests/Source/VisualTests/CaptureScreen.cpp"
        )

        if is_plat("windows") then
            add_ldflags("/SUBSYSTEM:WINDOWS", {force = true})
        end

        if is_toolchain("clang", "gcc") then
            add_cxxflags("-Wall", "-Wextra", "-pedantic")
        elseif is_toolchain("msvc") then
            add_cxxflags("/W4", "/w44062", "/permissive-")
            add_defines("_CRT_SECURE_NO_WARNINGS")
        end

end -- tests
