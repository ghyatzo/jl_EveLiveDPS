# using LibCImGui
# using ImGuiGLFWBackend
# using ImGuiOpenGLBackend
# using ImGuiGLFWBackend.GLFW
# using ImGuiOpenGLBackend.ModernGL

# const ig = LibCImGui

using CImGui
using CImGui.GLFWBackend
using CImGui.OpenGLBackend
using CImGui.GLFWBackend.GLFW
using CImGui.OpenGLBackend.ModernGL
using ImPlot

@static if Sys.isapple()
    # OpenGL 3.2 + GLSL 150
    global glsl_version = 150
    GLFW.WindowHint(GLFW.CONTEXT_VERSION_MAJOR, 3)
    GLFW.WindowHint(GLFW.CONTEXT_VERSION_MINOR, 2)
    GLFW.WindowHint(GLFW.OPENGL_PROFILE, GLFW.OPENGL_CORE_PROFILE) # 3.2+ only
    GLFW.WindowHint(GLFW.OPENGL_FORWARD_COMPAT, GL_TRUE) # required on Mac
else
    # OpenGL 3.0 + GLSL 130
    global glsl_version = 130
    GLFW.WindowHint(GLFW.CONTEXT_VERSION_MAJOR, 3)
    GLFW.WindowHint(GLFW.CONTEXT_VERSION_MINOR, 0)
    # GLFW.WindowHint(GLFW.OPENGL_PROFILE, GLFW.OPENGL_CORE_PROFILE) # 3.2+ only
    # GLFW.WindowHint(GLFW.OPENGL_FORWARD_COMPAT, GL_TRUE) # 3.0+ only
end

error_callback(err::GLFW.GLFWError) = @error "GLFW ERROR: code $(err.code) msg: $(err.description)"

function init_renderer(width, height, title::AbstractString)
    # setup GLFW error callback
    GLFW.SetErrorCallback(error_callback)

    # create window
    window = GLFW.CreateWindow(width, height, title)
    @assert window != C_NULL
    GLFW.MakeContextCurrent(window)
    GLFW.SwapInterval(1)  # enable vsync

    # setup Dear ImGui context and ImPlot context
    ctx = CImGui.CreateContext()
    ctxp = ImPlot.CreateContext()
    ImPlot.SetImGuiContext(ctx)

    # setup Dear ImGui style
    CImGui.StyleColorsDark()
    # CImGui.StyleColorsClassic()
    # CImGui.StyleColorsLight()

    # setup Platform/Renderer bindings
    ImGui_ImplGlfw_InitForOpenGL(window, true)
    ImGui_ImplOpenGL3_Init(glsl_version)

    # # load Fonts
	# # - If no fonts are loaded, dear imgui will use the default font. You can also load multiple fonts and use `CImGui.PushFont/PopFont` to select them.
	# # - `CImGui.AddFontFromFileTTF` will return the `Ptr{ImFont}` so you can store it if you need to select the font among multiple.
	# # - If the file cannot be loaded, the function will return C_NULL. Please handle those errors in your application (e.g. use an assertion, or display an error and quit).
	# # - The fonts will be rasterized at a given size (w/ oversampling) and stored into a texture when calling `CImGui.Build()`/`GetTexDataAsXXXX()``, which `ImGui_ImplXXXX_NewFrame` below will call.
	# # - Read 'fonts/README.txt' for more instructions and details.
	# fonts_dir = joinpath(@__DIR__, "..", "fonts")
	# fonts = CImGui.GetIO().Fonts
	# # default_font = CImGui.AddFontDefault(fonts)
	# # CImGui.AddFontFromFileTTF(fonts, joinpath(fonts_dir, "Cousine-Regular.ttf"), 15)
	# # CImGui.AddFontFromFileTTF(fonts, joinpath(fonts_dir, "DroidSans.ttf"), 16)
	# # CImGui.AddFontFromFileTTF(fonts, joinpath(fonts_dir, "Karla-Regular.ttf"), 10)
	# # CImGui.AddFontFromFileTTF(fonts, joinpath(fonts_dir, "ProggyTiny.ttf"), 10)
	# # CImGui.AddFontFromFileTTF(fonts, joinpath(fonts_dir, "Roboto-Medium.ttf"), 16)
	# CImGui.AddFontFromFileTTF(fonts, joinpath(fonts_dir, "Recursive Mono Casual-Regular.ttf"), 16)
	# CImGui.AddFontFromFileTTF(fonts, joinpath(fonts_dir, "Recursive Mono Linear-Regular.ttf"), 16)
	# CImGui.AddFontFromFileTTF(fonts, joinpath(fonts_dir, "Recursive Sans Casual-Regular.ttf"), 16)
	# CImGui.AddFontFromFileTTF(fonts, joinpath(fonts_dir, "Recursive Sans Linear-Regular.ttf"), 16)
	# # @assert default_font != C_NULL

    return window, ctx, ctxp
end

function renderpass(ui, window, ctx, ctxp, clearcolor, hotloading=false)
	GLFW.PollEvents()
    ImGui_ImplOpenGL3_NewFrame()
    ImGui_ImplGlfw_NewFrame()
    CImGui.NewFrame()

    hotloading ? Base.invokelatest(ui) : ui()

    CImGui.Render()
    GLFW.MakeContextCurrent(window)
    display_w, display_h = GLFW.GetFramebufferSize(window)
    glViewport(0, 0, display_w, display_h)
    glClearColor(clearcolor...)
    glClear(GL_COLOR_BUFFER_BIT)
    ImGui_ImplOpenGL3_RenderDrawData(CImGui.GetDrawData())

    GLFW.MakeContextCurrent(window)
    GLFW.SwapBuffers(window)
    yield()
end

function renderloop(window, ctx, ctxp, clearcolor, ui=()->nothing, destructor=()->nothing, hotloading=false)
    try
        while !GLFW.WindowShouldClose(window)
          	renderpass(ui, window, ctx, ctxp, clearcolor, hotloading)
        end
    catch e
        Base.error("Error in renderloop: $e")
    finally
    	destructor()

        ImGui_ImplOpenGL3_Shutdown()
        ImGui_ImplGlfw_Shutdown()
        ImPlot.DestroyContext(ctxp)
        CImGui.DestroyContext(ctx)
        GLFW.HideWindow(window)
        GLFW.DestroyWindow(window)
    end
end

function render(ui; width=1280, height=720, title::AbstractString="Demo", clearcolor=[0.0, 0.0, 0.0, 1.0], hotloading=false)
    window, ctx, ctxp = init_renderer(width, height, title)
    GC.@preserve window ctx ctxp begin
        t = renderloop(window, ctx, ctxp, clearcolor, ui, ()->nothing, hotloading)
    end
    return t
end
