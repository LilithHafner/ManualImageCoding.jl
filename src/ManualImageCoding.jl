module ManualImageCoding

# Features wishlist:
# Free Text (one line)
# Free text (multiple lines)
# Binary & categorical
# Automatically classified data type
# Multiple entries per image
# Automatic column names

using Gtk, Random, DataFrames, CSV, Dates

export main

# function index(path)
#     df = DataFrame(root=String[], path=String[], mtime=Float64[], is_dir=BitVector())
#     function insert(root, leaf, dir)
#         p = joinpath(root, leaf)
#         mtime = stat(p).mtime # most of the runtime
#         push!(df, (relpath(root, path), relpath(p, path), mtime, dir))
#     end
#     for (root, dirs, files) in walkdir(path)
#         insert.((root,), dirs, true)
#         insert.((root,), files, false) # most of the runtime
#     end
#     df
# end

const isimage01 = endswith(r".(JPG|PNG|GIF|WEBP|TIFF|PSD|RAW|BMP|HEIF|INDD|JPEG)"i)

# function label_images!(df::DataFrame)
#     df.is_image = .!df.is_dir .& isimage01.(df.path)
#     df
# end

# print_tree(path) = print_tree(stdout, path)
# function print_tree(io::IO, path, info=nothing) # indentation based
#     base = length(splitpath(path))
#     for (root, dirs, files) in walkdir(path)
#         println(io, "  "^(length(splitpath(root))-base), basename(root), info===nothing ? "" : info(root, dirs, files))
#     end
# end
function print_tree(io::IO, path, info=nothing)
    for (root, dirs, files) in Iterators.Drop(walkdir(path), 1)
        println(io, joinpath(splitpath(root)[2:end]), info===nothing ? "" : info(root, dirs, files))
    end
end

function israndomized(str)
    startswith(str, r"\d\d\d\d\d\d\d\d_") || return false
    x = parse(Int, str[1:6])
    y = parse(Int, str[7:8])
    hash(x) % 100 == y
end

function randomize_name(str)
    x = rand(0:999999)
    y = hash(x) % 100
    "$x$(y)_$str"
end

function randomize_dirs(path)
    for name in readdir(path)
        israndomized(name) && continue
        p = joinpath(path, name)
        isdir(p) && mv(p, joinpath(path, randomize_name(name)))
    end
end

function print_marked_tree(io, path, coded=())
    marker_printed::Bool = false
    function info(root, _, files)
        occursin(r"\(skip\)$", root) && return ""
        filter!(isimage01, files)
        isempty(files) && return ""
        paths = relpath.(joinpath.((root,), files), (path,))
        n_coded = count(in(coded), paths)
        out = " ($n_coded/$(length(paths)))"
        n_coded == length(paths) && return out
        marker_printed && return out
        marker_printed = true
        return out * " <--"
    end
    print_tree(io, path, info)
end
function print_marked_tree(::Type{String}, args...)
    b = IOBuffer()
    print_marked_tree(b, args...)
    String(take!(b))
end

function read_marked_tree(path, tree)
    out = nothing
    for line in split(tree, '\n')
        line = strip(line)
        arrow_match = match(r"<-+$", line)
        off = arrow_match === nothing ? lastindex(line)+1 : arrow_match.offset
        line = strip(line[begin:off-1])
        paren_match = match(r"\([^()]*\)$", line)
        off = paren_match === nothing ? lastindex(line)+1 : paren_match.offset
        line = strip(line[begin:off-1])
        if arrow_match !== nothing && out === nothing
            out = line
            ispath(line*" (skip)") && mv(line*" (skip)", line)
        elseif paren_match !== nothing && occursin(r"skip"i, paren_match.match) && ispath(line)
            mv(line, line*" (skip)")
        elseif (paren_match === nothing || !occursin(r"skip"i, paren_match.match)) && ispath(line*" (skip)")
            mv(line*" (skip)", line)
        end
    end
    out
end

function prompt_for_file(w, path, coded)
    box = GtkBox(:v)
    push!(w, box)
    text = GtkTextBuffer()
    text.text[String] = print_marked_tree(String, path, coded)
    textview = GtkTextView(text, vexpand=true)
    push!(box, textview)
    button = GtkButton(label="Confirm")
    push!(box, button)
    show(textview)
    show(button)
    show(box)

    c = Channel{Int}()
    callback(_) = put!(c, 0)
    signal_connect(callback, button, "clicked")

    # command+enter
    @guarded signal_connect(textview, "key-press-event") do _, event
        # The key is enter    && Any non-capslock modifier is pressed
        event.keyval == 65293 #=&& event.state & 0x11111101 != 0=# && put!(c, 1)
        nothing
    end
    # enter_event = @guarded signal_connect(w, "key-press-event") do _, event
    #     # The key is enter    && Any non-capslock modifier is pressed
    #     event.keyval == 65293 #=&& event.state & 0x11111101 != 0=# && put!(c, 1)
    #     nothing
    # end
    delete_event = @guarded signal_connect(w, "delete-event") do _, event
        put!(c, 2)
        nothing
    end

    status = take!(c)
    sleep(.001)
    status == 2 && return nothing

    tree = text.text[String]
    if status == 1
        pos = text.cursor_position[Int]
        if tree[pos] == '\n'
            tree = tree[begin:pos-1]*tree[pos+1:end]
        else
            println("WARNING LH-01")
        end
    end

    signal_handler_disconnect(w, delete_event)
    # signal_handler_disconnect(w, enter_event)
    destroy(textview)
    destroy(button)
    destroy(box)

    read_marked_tree(path, tree)
end

headers() = :path, :camera_station, :time, :species, :count, :coder, :image_name, :coding_time, :time_unix, :coding_time_unix, :camera_station_number, :notes
function load(path)
    p = joinpath(path, "data.csv")
    out = Dict{String, NamedTuple{headers(), NTuple{length(headers()), String}}}()
    if isfile(p)
        for row in CSV.File(p)
            out[row.path] = (;(k=>v === missing ? "" : string(v) for (k,v) in pairs(row))...)
        end
    else
        open(p, "w") do io
            join(io, headers(), ',')
            println(io)
        end
    end
    out
end

function save(root_path; kw...)
    buf = IOBuffer()
    join(buf, (kw[h] for h in headers()), ',')
    open(joinpath(root_path, "data.csv"), "a") do io
        println(io, String(take!(buf)))
    end
    nothing
end

function record(root_path, data; kw...)
    data[kw[:path]] = values(kw)
    save(root_path; kw...)
end

function code(w, root_path, rel_path, data)
    # Relative path; camera station name; coder; coding time; image time; species; count; notes
    # count default = species is explicit ? 1 : 0
    # s[ecies default = blank
    # camera station name & coder are inferred and carried forward when edited
    # coding time and image time are inferred and unedditable
    # notes are blank by default
    # timex in unix & date string

    vbox = GtkBox(:v)
    push!(w, vbox)
    hbox = GtkBox(:h)
    push!(vbox, hbox)

    progress_display = GtkLabel("Progress", margin=8)
    push!(hbox, progress_display)
    path_display = GtkLabel("Path", margin=8)
    push!(hbox, path_display)
    time_display = GtkLabel("Time", margin=8)
    push!(hbox, time_display)

    hbox2 = GtkBox(:h)
    push!(vbox, hbox2)

    species = GtkEntry(text="Species", margin=8)
    push!(hbox2, species)
    count = GtkEntry(text="Count", margin=8)
    push!(hbox2, count)
    notes = GtkEntry(text="Notes", margin=8)
    push!(hbox2, notes)

    coder = GtkEntry(text="Coder", margin=8)
    push!(hbox2, coder)
    camera_station = GtkEntry(text="Camera station", margin=8)
    push!(hbox2, camera_station)

    prev_button = GtkButton(label="⟨", margin=8)
    push!(hbox2, prev_button)
    next_button = GtkButton(label="⟩", margin=8)
    push!(hbox2, next_button)

    image = Gtk.GtkImage()
    push!(vbox, image)

    show(progress_display)
    show(path_display)
    show(time_display)
    show(species)
    show(count)
    show(notes)
    show(coder)
    show(camera_station)
    show(prev_button)
    show(next_button)

    show(image)
    show(hbox)
    show(hbox2)
    show(vbox)


    c = Channel{Bool}()
    i::Int = 1
    exit::Bool = false

    function show_image(p)
        aspect = 16//9 # resize and display image
        wid = min(width(w), round(Int, (height(w)-height(hbox)-height(hbox2))*aspect))
        pixbuf = GdkPixbuf(filename=p, width=wid)
        image.pixbuf[typeof(pixbuf)] = pixbuf
    end
    @guarded function next(args...)
        i += 1
        put!(c, true)
        nothing
    end
    @guarded function prev(args...)
        i -= 1
        put!(c, true)
        nothing
    end

    signal_connect(next, next_button, "clicked")
    signal_connect(prev, prev_button, "clicked")
    delete_event = signal_connect(w, "delete-event") do _, event
        exit = true
        put!(c, false)
        nothing
    end
    for e in [species, count, notes, coder, camera_station]#Iterators.flatten((hbox2, (w,))) # enter / shift+ender
        signal_connect(e, "key-press-event") do _, event
            if event.keyval == 65293 # The key is enter
                if event.state & 0x1 != 0 # Shift is pressed
                    prev()
                else
                    next()
                end
            end
            nothing
        end
    end
    signal_connect(species, "changed") do _ # Automatically populate count
        if species.text[String] == ""
            if count.text[String] == "1"
                count.text[String] = ""
            end
        elseif count.text[String] == ""
            count.text[String] = "1"
        end
    end

    path = joinpath(root_path, rel_path)
    dirs = filter!(readdir(path)) do file
        isimage01(file) && isfile(joinpath(path, file))
    end
    while i <= lastindex(dirs) && joinpath(rel_path, dirs[i]) ∈ keys(data)
        i += 1
    end
    if i == lastindex(dirs)
        i = 1
    end
    while true
        checkbounds(Bool, dirs, i) || (sleep(.001); destroy(vbox); signal_handler_disconnect(w, delete_event); break)
        file = dirs[i]
        p = joinpath(rel_path, file)

        previous_coding = get(data, p, nothing)
        if previous_coding === nothing
            species.text[String] = ""
            notes.text[String] = ""
            count.text[String] = ""
        else
            species.text[String] = previous_coding.species
            count.text[String] = previous_coding.count
            notes.text[String] = previous_coding.notes
            coder.text[String] = previous_coding.coder
            camera_station.text[String] = previous_coding.camera_station
        end

        rp = joinpath(rel_path, file)
        t = mtime(joinpath(root_path, p))
        time_string = string(unix2datetime(t) + Hour(6))

        path_display.label[String] = rp
        time_display.label[String] = time_string # 6 hours for time zone

        show_image(joinpath(root_path, p))

        ok = take!(c)
        sleep(.001)
        ok || break

        record(root_path, data;
            path=p,
            camera_station=camera_station.text[String],
            time=time_string,
            species=species.text[String],
            count=count.text[String],
            coder=coder.text[String],
            image_name = file,
            coding_time = string(now()),
            time_unix = string(t),
            coding_time_unix = string(time()),
            camera_station_number=string(split(basename(rel_path), '_')[1]),
            notes=notes.text[String])
    end

    #=destroy(path_display)
    destroy(time_display)
    destroy(species)
    destroy(count)
    destroy(notes)
    destroy(coder)
    destroy(camera_station)
    destroy(prev_button)
    destroy(next_button)

    destroy(image)
    destroy(hbox)
    destroy(hbox2)
    destroy(vbox)=#

    exit
end

function main(root_path = ".")
    println("Started")
    data = load(root_path)# possible bottleneck, but probably fine.
    println("Data loaded")
    w = GtkWindow("GUI")
    try
        while true
            path = prompt_for_file(w, root_path, keys(data))
            path === nothing && break
            exit = code(w, root_path, path, data)
            exit && break
        end
    finally
        destroy(w)
    end
    println("Finished")
end

_code(;path, kw...) = _code(path; kw...)
function _code(path::AbstractString; title="Coding", coding_file_name="codings.csv", delim=", ", width=1100, verbose=true, shuffle=true)

    # search for images
    files = String[]
    for (root, _, fs) in walkdir(path), file in fs
        filename = joinpath(root, file)
        ufn = uppercase(filename[max(begin, end-4):end])
        any(endswith(ufn, ext) for ext in EXTENSIONS) && push!(files, filename)
    end

    total = length(files)
    total == 0 && (println("WARNING: No images found in $path"); return)

    # get uncoded images

    for f in files
        occursin(delim, joinpath(path, f)) && println("WARNING: Delimiter \"$delim\" found in file \"$f\". Consider renaming the file.")
    end
    filename = joinpath(path, coding_file_name)
    if isfile(filename)
        coded = open(filename, "r") do f
            Set(first(split(line, delim)) for line in readlines(f))
        end
        filter!(x -> !(relpath(x, path) in coded), files)
    end
    shuffle && shuffle!(files)
    verbose && println("$(total-length(files))/$total ($(round(Int, 100*(total-length(files))/total))%) images coded. $(length(files)) left.")

    # present the images to the user for coding

    w = GtkWindow(title)
    c = Channel{Bool}()

    keys = UInt8[]

    @guarded signal_connect(w, "key-press-event") do _, event
        # The key is enter    && Any non-capslock modifier is pressed
        event.keyval == 65293 && #=event.state & 0x11111101 != 0 &&=# put!(c, false)
        # The key is escape
        event.keyval == 65307 && (Gtk.destroy(w); put!(c, true))
        # The key is ascii
        event.keyval <= 128 && push!(keys, event.keyval)
        nothing
    end

    @guarded signal_connect(w, "delete-event") do _, event
        put!(c, true)
        nothing
    end

    open(joinpath(path, coding_file_name), "a") do io
        i = nothing
        for file in files # For each image file
            sleep(.001) # Hand control back to Gtk
            i === nothing || destroy(i)
            i = Gtk.GtkImage(Gtk.GdkPixbuf(;filename=file, width))
            push!(w, i)
            resize!(w, 1, 1)
            show(i)
            sleep(.001)

            take!(c) && break # If someone makes a typo, they can exit. Save on explicit enter only.

            str = relpath(file, path) * delim * String(keys) * '\n'
            write(io, str)
            flush(io)
            verbose && print(str)

        end
    end
end

# function julia_main()::Cint
#     s = ArgParseSettings()
#     @add_arg_table! s begin
#         "--path"
#             help = "the path to the directory containing the images to code"
#             arg_type = String
#             default = @__DIR__
#         "--coding_file_name"
#             help = "the file name to use when loading and saving the codings"
#             arg_type = String
#             default = "codings.csv"
#         "--delim"
#             help = "the delimiter to use when loading and saving the codings"
#             arg_type = String
#             default = ", "
#         "--width"
#             help = "the width of the images to display"
#             arg_type = Int
#             default = 1100
#         "--verbose"
#             help = "whether to print output to the command-line"
#             arg_type = Bool
#             default = true
#         "--shuffle"
#             help = "whether to shuffle the images before coding"
#             arg_type = Bool
#             default = true
#     end
#     parsed_args = parse_args(s, as_symbols=true)
#     code(;parsed_args...)

#     return 0 # if things finished successfully
# end

# if abspath(PROGRAM_FILE) == @__FILE__
#     julia_main()
# end

end