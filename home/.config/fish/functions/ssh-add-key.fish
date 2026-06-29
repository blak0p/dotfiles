function ssh-add-key --description "Add SSH key if not loaded"
    if not ssh-add -l >/dev/null 2>&1
        ssh-add ~/.ssh/id_ed25519 2>/dev/null
    end
end
