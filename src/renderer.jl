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

    io = CImGui.GetIO()
    io.ConfigFlags = unsafe_load(io.ConfigFlags) | CImGui.ImGuiConfigFlags_DockingEnable
    io.ConfigFlags = unsafe_load(io.ConfigFlags) | CImGui.ImGuiConfigFlags_ViewportsEnable

    # setup Dear ImGui style
    CImGui.StyleColorsDark()
    # CImGui.StyleColorsClassic()
    # CImGui.StyleColorsLight()

    # setup Platform/Renderer bindings
    glfw_ctx = ImGuiGLFWBackend.create_context(window, install_callbacks = true)
    ImGuiGLFWBackend.init(glfw_ctx)
    opengl_ctx = ImGuiOpenGLBackend.create_context(glsl_version)
    ImGuiOpenGLBackend.init(opengl_ctx)

    return window, ctx, ctxp, glfw_ctx, opengl_ctx, io
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

    if unsafe_load(CImGui.GetIO().ConfigFlags) & CImGui.ImGuiConfigFlags_ViewportsEnable == CImGui.ImGuiConfigFlags_ViewportsEnable
        backup_current_context = glfwGetCurrentContext()
        CImGui.igUpdatePlatformWindows()
        GC.@preserve opengl_ctx CImGui.igRenderPlatformWindowsDefault(C_NULL, pointer_from_objref(opengl_ctx))
        glfwMakeContextCurrent(backup_current_context)
    end 

    glfwSwapBuffers(window)
    yield()
end

function renderloop(window, ctx, ctxp, glfw_ctx, opengl_ctx, imIO, framerate_cap, clearcolor, ui=()->nothing, destructor=()->nothing, hotloading=false)
    target_dt = inv(framerate_cap)
    try
        while glfwWindowShouldClose(window) == 0
            dt = unsafe_load(imIO.DeltaTime)
            if dt < target_dt
                sleep(target_dt -dt)
            end
          	renderpass(ui, window, ctx, ctxp, glfw_ctx, opengl_ctx, clearcolor, hotloading)
        end
    catch e
        println(stdout, "Error in renderloop!", e)
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
    GC.@preserve window ctx ctxp begin
        t = renderloop(window, ctx, ctxp, glfw_ctx, opengl_ctx, clearcolor, ui, ()->nothing, hotloading)
    end
    return t
end
