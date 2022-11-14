module ManualImageCoding

# Features:
# Free Text (one line)
# Free text (multiple lines)
# Binary & categorical
# Automatically classified data type
# Multiple entries per image
# Automatic column names

using Gtk, Random

export code

const IMAGE_EXTENSIONS = [".png", ".jpg", ".jpeg"]
const FILE_NAME = "codings.csv"
const DELIM = ", "
is_image_path(path) = any(endswith(path, ext) for ext in IMAGE_EXTENSIONS)

function search(path::AbstractString; recursive::Bool=true, filter::Function=is_image_path)
    out = String[]
    for (root, _, files) in walkdir(path)
        for file in files
            filename = joinpath(root, file)
            filter(filename) && push!(out, filename)
        end
        !recursive && break
    end
    out
end

function get_uncoded(path::AbstractString; shuffle=true, verbose=true, kw...)
    out = search(path; kw...)
    total = length(out)
    for f in out
        occursin(DELIM, joinpath(path, f)) && println("WARNING: Delimiter \"$DELIM\" found in file \"$f\". Consider renaming the file.")
    end
    filename = joinpath(path, FILE_NAME)
    if isfile(filename)
        coded = open(filename, "r") do f
            Set(first(split(line, DELIM)) for line in readlines(f))
        end
        filter!(x -> !(relpath(x, path) in coded), out)
    end
    shuffle && shuffle!(out)
    verbose && println("$(total-length(out))/$total ($(round(Int, 100*(total-length(out))/total))%) images coded. $(length(out)) left.")
    out
end

function code(path::AbstractString; title="Coding")
    w = GtkWindow(title)
    c = Channel{Bool}()

    keys = UInt8[]

    @guarded signal_connect(w, "key-press-event") do _, event
        # The key is enter    && Any non-shift modifier is pressed
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

    files = get_uncoded(path)
    open(joinpath(path, FILE_NAME), "a") do io
        i = nothing
        for file in files # For each image file
            sleep(.001) # Hand control back to Gtk
            i === nothing || destroy(i)
            i = Gtk.GtkImage(file)
            push!(w, i)

            show(i)
            resize!(w, 500, 500)
            sleep(.001)

            take!(c) && break # If someone makes a typo, they can exit. Save on explicit enter only.

            str = relpath(file, path) * DELIM * String(keys) * '\n'
            write(io, str)
            flush(io)
            print(str)

        end
    end
end

end