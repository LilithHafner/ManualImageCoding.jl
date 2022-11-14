module ManualImageCoding

# Features:
# Free Text (one line)
# Free text (multiple lines)
# Binary & categorical
# Automatically classified data type
# Multiple entries per image
# Automatic column names

testimages = ["airplaneF16", "autumn_leaves", "barbara_color", "barbara_gray_512", "bark_512", "bark_he_512", "beach_sand_512", "beach_sand_he_512", "blobs", "brick_wall_512", "brick_wall_he_512", "calf_leather_512", "calf_leather_he_512", "cameraman", "chelsea", "coffee", "earth_apollo17", "fabio_color_256", "fabio_color_512", "fabio_gray_256", "fabio_gray_512", "grass_512", "grass_he_512", "hela-cells", "herringbone_weave_512", "herringbone_weave_he_512", "house", "jetplane", "lake_color", "lake_gray", "lena_color_256", "lena_color_512", "lena_gray_16bit", "lena_gray_256", "lena_gray_512", "lighthouse", "livingroom", "m51", "mandril_color", "mandril_gray", "mandrill", "monarch_color", "monarch_color_256", "moonsurface", "morphology_test_512", "mountainstream", "mri-stack", "multi-channel-time-series.ome", "peppers_color", "peppers_gray", "pigskin_512", "pigskin_he_512", "pirate", "plastic_bubbles_512", "plastic_bubbles_he_512", "raffia_512", "raffia_he_512", "resolution_test_1920", "resolution_test_512", "simple_3d_ball", "simple_3d_psf", "straw_512", "straw_he_512", "sudoku", "toucan", "walkbridge", "water_512", "water_he_512", "woman_blonde", "woman_darkhair", "wood_grain_512", "wood_grain_he_512", "woolen_cloth_512", "woolen_cloth_he_512"]
image_extensions = [".png", ".jpg", ".jpeg"]
imgpath = "../../../Desktop/img.png"

using Gtk, TestImages

export imshow, imshowall, page, imgpath

function imshow(filename::AbstractString; title="Image")
    isfile(filename) || error("File not found: $filename")
    i = Gtk.GtkImage(filename)
    w = GtkWindow(i, "Image")
    show(i)
    nothing
end

function imshowall(path::AbstractString; limit=10, kw...)
    for (root, _, files) in walkdir(path)
        for file in files
            filename = joinpath(root, file)
            if any(endswith(filename, ext) for ext in image_extensions)
                imshow(filename; kw...)
                limit -= 1
                limit <= 0 && return
            end
        end
    end
end

@guarded function page(path::AbstractString; title="Images")
    w = GtkWindow(title)
    c = Channel{Bool}()

    @guarded signal_connect(w, "key-press-event") do _, event
        exit = event.keyval ∈ (113, 119)
        exit && Gtk.destroy(w) # q, w
        put!(c, exit)
        nothing
    end

    @guarded signal_connect(w, "delete-event") do _, event
        put!(c, true)
        nothing
    end

    i = nothing
    for (root, _, files) in walkdir(path)
        for file in files
            filename = joinpath(root, file)
            if any(endswith(filename, ext) for ext in image_extensions)
                sleep(.001) # Hand control back to Gtk
                i === nothing || destroy(i)
                i = Gtk.GtkImage(filename)
                push!(w, i)
                show(i)
                take!(c) && return
            end
        end
    end

end

end