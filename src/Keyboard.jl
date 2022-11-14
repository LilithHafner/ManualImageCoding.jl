struct Keyboard
    parent::GtkWindowLeaf
    keys_down::Set{UInt32}
    function Keyboard(window; exit_on_command_q=true, exit_on_command_w=true)
        keys_down = Set{UInt32}()
        signal_connect(window, "key-press-event") do widget, event
            push!(keys_down, event.keyval)
            println(event.state)
            if exit_on_command_q && event.keyval == 113 && 65511 ∈ keys_down
                Gtk.destroy(window)
            end
            if exit_on_command_w && event.keyval == 119 && 65511 ∈ keys_down
                Gtk.destroy(window)
            end
            nothing
        end

        @guarded signal_connect(window, "key-release-event") do widget, event
            pop!(keys_down, event.keyval)
            nothing
        end
        new(window, keys_down)
    end
end

ispressed(keyboard::Keyboard, key::Integer) = key ∈ keyboard.keys_down
ispressed(keyboard::Keyboard, key::Char) = ispressed(keyboard, UInt32(key))
