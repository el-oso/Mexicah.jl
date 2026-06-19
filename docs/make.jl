using Documenter, DocumenterVitepress, Mexicah

makedocs(;
    modules = [Mexicah],
    sitename = "Mexicah.jl",
    authors = "el_oso",
    format = DocumenterVitepress.MarkdownVitepress(;
        repo = "github.com/el-oso/Mexicah.jl",
        devbranch = "master",
        devurl = "dev",
        sidebar_drawer = true,
    ),
    pages = [
        "Home" => "index.md",
        "Guide" => [
            "guide/installation.md",
            "guide/quickstart.md",
            "guide/runtime.md",
            "guide/comparison.md",
        ],
        "Examples" => [
            "examples/index.md",
            "examples/scalar.md",
            "examples/matrix.md",
            "examples/sparse.md",
            "examples/handles.md",
            "examples/linalg.md",
        ],
        "Reference" => [
            "reference/api.md",
            "reference/cli.md",
            "reference/marshaling.md",
        ],
        "Internals" => [
            "internals/architecture.md",
            "internals/contracts.md",
        ],
    ],
    checkdocs = :exports,
    warnonly = [:missing_docs],
    remotes = nothing,
    doctest = false,
)

DocumenterVitepress.deploydocs(;
    repo = "github.com/el-oso/Mexicah.jl",
    devbranch = "master",
    push_preview = true,
)
