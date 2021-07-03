using Remark, FileWatching

while true
    Remark.slideshow(@__DIR__; options = Dict("ratio" => "16:9"), title = "Presentation")
    run(`cp docs/introtalk/aot.jpg docs/introtalk/jaot.jpg docs/introtalk/jit.png docs/introtalk/build`)
    @info "Rebuilt"
    FileWatching.watch_folder(joinpath(@__DIR__, "src"))
end
