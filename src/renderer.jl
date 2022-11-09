# using LibCImGui
# using ImGuiGLFWBackend
# using ImGuiOpenGLBackend
# using ImGuiGLFWBackend.GLFW
# using ImGuiOpenGLBackend.ModernGL

# const ig = LibCImGui

using CImGui
using CImGui.ImGuiGLFWBackend
using CImGui.ImGuiOpenGLBackend
using CImGui.ImGuiGLFWBackend.LibGLFW
using CImGui.ImGuiOpenGLBackend.ModernGL
using ImPlot

@static if Sys.isapple()
    # OpenGL 3.2 + GLSL 150
    global glsl_version = 150
    glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3)
    glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 2)
    glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE) # 3.2+ only
    glfwWindowHint(GLFW_OPENGL_FORWARD_COMPAT, GL_TRUE) # required on Mac
else
    # OpenGL 3.0 + GLSL 130
    global glsl_version = 130
    glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3)
    glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 0)
    # glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE) # 3.2+ only
    # glfwWindowHint(GLFW_OPENGL_FORWARD_COMPAT, GL_TRUE) # 3.0+ only
end

# error_callback(err::GLFW.GLFWError) = @error "GLFW ERROR: code $(err.code) msg: $(err.description)"

function init_renderer(width, height, title::AbstractString)
    # setup GLFW error callback
    # GLFW.SetErrorCallback(error_callback)

    # create window
    window = glfwCreateWindow(width, height, title, C_NULL, C_NULL)
    @assert window != C_NULL
    glfwMakeContextCurrent(window)
    glfwSwapInterval(1)  # enable vsync

    # setup Dear ImGui context and ImPlot context
    ctx = CImGui.CreateContext()
    ctxp = ImPlot.CreateContext()
    ImPlot.SetImGuiContext(ctx)

    # setup Dear ImGui style
    CImGui.StyleColorsDark()
    # CImGui.StyleColorsClassic()
    # CImGui.StyleColorsLight()

    # setup Platform/Renderer bindings
    glfw_ctx = ImGuiGLFWBackend.create_context(window, install_callbacks = true)
    ImGuiGLFWBackend.init(glfw_ctx)
    opengl_ctx = ImGuiOpenGLBackend.create_context(glsl_version)
    ImGuiOpenGLBackend.init(opengl_ctx)

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

    return window, ctx, ctxp, glfw_ctx, opengl_ctx
end

function renderpass(ui, window, ctx, ctxp, glfw_ctx, opengl_ctx, clearcolor, hotloading=false)
	glfwPollEvents()
    ImGuiOpenGLBackend.new_frame(opengl_ctx)
    ImGuiGLFWBackend.new_frame(glfw_ctx)
    CImGui.NewFrame()

    hotloading ? Base.invokelatest(ui) : ui()

    CImGui.Render()
    glfwMakeContextCurrent(window)
    width, height = Ref{Cint}(), Ref{Cint}()
    glfwGetFramebufferSize(window, width, height)
    display_w = width[]
    display_h = height[]
    glViewport(0, 0, display_w, display_h)
    glClearColor(clearcolor...)
    glClear(GL_COLOR_BUFFER_BIT)
    ImGuiOpenGLBackend.render(opengl_ctx)

    glfwMakeContextCurrent(window)
    glfwSwapBuffers(window)
    yield()
end

function renderloop(window, ctx, ctxp, glfw_ctx, opengl_ctx, clearcolor, ui=()->nothing, destructor=()->nothing, hotloading=false)
    try
        while glfwWindowShouldClose(window) == 0
          	renderpass(ui, window, ctx, ctxp, glfw_ctx, opengl_ctx, clearcolor, hotloading)
        end
    catch e
        @error "Error in renderloop!" exception=e
        Base.show_backtrace(stderr, catch_backtrace())
    finally
    	destructor()

        ImGuiOpenGLBackend.shutdown(opengl_ctx)
        ImGuiGLFWBackend.shutdown(glfw_ctx)
        ImPlot.DestroyContext(ctxp)
        CImGui.DestroyContext(ctx)
        glfwDestroyWindow(window)
    end
end

function render(ui; width=1280, height=720, title::AbstractString="JlEveLiveDps", clearcolor=[0.0, 0.0, 0.0, 1.0], hotloading=false)
    window, ctx, ctxp , glfw_ctx, opengl_ctx = init_renderer(width, height, title)
    @show typeof.([window, ctx, ctxp , glfw_ctx, opengl_ctx ])
    GC.@preserve window ctx ctxp begin
        t = renderloop(window, ctx, ctxp, glfw_ctx, opengl_ctx, clearcolor, ui, ()->nothing, hotloading)
    end
    return t
end
