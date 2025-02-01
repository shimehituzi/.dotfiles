function pjcopy
    if not git rev-parse --is-inside-work-tree > /dev/null 2>&1
        echo "Not a Git repository." 1>&2
        return 1
    end

    if test (count $argv) -eq 0
        echo "Usage: pjcopy EXT1 [EXT2 ...]"
        return 1
    end

    set pattern (string join "|" $argv)
    set allfiles (git ls-files --cached --others --exclude-standard)
    set filtered (string match -r '^.*\.(?:'"$pattern"')$' $allfiles)

    if test (count $filtered) -eq 0
        echo "No matching files."
        return 0
    end

    begin
        for f in $filtered
            echo "## $f"
            echo '```'
            cat "$f"
            echo '```'
            echo
        end
    end | pbcopy
end
