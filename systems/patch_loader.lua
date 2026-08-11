--========================================================--
-- IRON SOUL - IMMUTABLE BASE PATCH LOADER V1
--
-- Loads an immutable historical source revision, applies one verified unified
-- diff stored in this repo, then compiles/executes the patched source.
--========================================================--

local function splitLines(text)
    text = tostring(text or "")
        :gsub("\r\n", "\n")
        :gsub("\r", "\n")

    local finalNewline =
        string.sub(text, -1) == "\n"

    if finalNewline then
        text = string.sub(text, 1, -2)
    end

    local out = {}

    if text ~= "" then
        for line in string.gmatch(
            text .. "\n",
            "(.-)\n"
        ) do
            table.insert(out, line)
        end
    end

    return out, finalNewline
end

local function applyUnifiedDiff(
    source,
    patch,
    targetPath
)
    local src,
        finalNewline =
            splitLines(source)

    local diff =
        select(1, splitLines(patch))

    if diff[1]
        ~= "--- a/" .. targetPath
        or diff[2]
            ~= "+++ b/" .. targetPath
    then
        error(
            "patch target mismatch for "
                .. tostring(targetPath)
        )
    end

    local out = {}
    local srcIndex = 1
    local i = 3

    local function copyUntil(lineNumber)
        while srcIndex < lineNumber do
            table.insert(
                out,
                src[srcIndex]
            )
            srcIndex += 1
        end
    end

    while i <= #diff do
        local line = diff[i]

        if string.sub(line, 1, 2)
            == "@@"
        then
            local oldStart,
                oldCount,
                newStart,
                newCount =
                    string.match(
                        line,
                        "^@@ %-(%d+),?(%d*) %+(%d+),?(%d*) @@"
                    )

            oldStart = tonumber(oldStart)

            if not oldStart then
                error(
                    "bad hunk header: "
                        .. tostring(line)
                )
            end

            copyUntil(oldStart)
            i += 1

            while i <= #diff
                and string.sub(
                    diff[i],
                    1,
                    2
                ) ~= "@@"
            do
                local row = diff[i]
                local prefix =
                    string.sub(row, 1, 1)

                local body =
                    string.sub(row, 2)

                if prefix == " " then
                    if src[srcIndex]
                        ~= body
                    then
                        error(
                            "patch context mismatch at source line "
                                .. tostring(srcIndex)
                                .. " for "
                                .. tostring(targetPath)
                        )
                    end

                    table.insert(out, body)
                    srcIndex += 1

                elseif prefix == "-" then
                    if src[srcIndex]
                        ~= body
                    then
                        error(
                            "patch removal mismatch at source line "
                                .. tostring(srcIndex)
                                .. " for "
                                .. tostring(targetPath)
                        )
                    end

                    srcIndex += 1

                elseif prefix == "+" then
                    table.insert(out, body)

                elseif prefix == "\\" then
                    -- "No newline at end of file" marker.

                elseif row ~= "" then
                    error(
                        "unexpected patch row: "
                            .. tostring(row)
                    )
                end

                i += 1
            end
        else
            i += 1
        end
    end

    while srcIndex <= #src do
        table.insert(
            out,
            src[srcIndex]
        )
        srcIndex += 1
    end

    local result =
        table.concat(out, "\n")

    if finalNewline then
        result ..= "\n"
    end

    return result
end

return function(opts)
    assert(
        type(opts) == "table",
        "patch loader options missing"
    )

    local repository =
        assert(opts.repository)

    local baseCommit =
        assert(opts.base_commit)

    local targetPath =
        assert(opts.path)

    local patchPaths =
        opts.patch_paths

    if type(patchPaths)
        ~= "table"
    then
        patchPaths = {
            assert(opts.patch_path),
        }
    end

    local baseUrl =
        "https://raw.githubusercontent.com/"
        .. repository
        .. "/"
        .. baseCommit
        .. "/"
        .. targetPath

    local patched =
        game:HttpGet(baseUrl)

    for index, patchPath in ipairs(
        patchPaths
    ) do
        local patchUrl =
            "https://raw.githubusercontent.com/"
            .. repository
            .. "/main/"
            .. patchPath
            .. "?is_patch="
            .. tostring(index)
            .. "&t="
            .. tostring(os.time())

        local patch =
            game:HttpGet(patchUrl)

        patched =
            applyUnifiedDiff(
                patched,
                patch,
                targetPath
            )
    end

    local fn, err =
        loadstring(patched)

    if not fn then
        error(
            "patched compile failed: "
                .. tostring(targetPath)
                .. " | "
                .. tostring(err)
        )
    end

    return fn()
end
