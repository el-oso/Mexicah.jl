using Documenter, DocumenterVitepress, Mexicah

makedocs(;
    modules = [Mexicah],
    sitename = "Mexicah.jl",
    authors = "el_oso",
    format = DocumenterVitepress.MarkdownVitepress(;
        devbranch = "master",
        repo = "github.com/el-oso/Mexicah.jl",
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
            "examples/ad_enzyme.md",
            "examples/mtk_ode.md",
            "examples/handles.md",
            "examples/dataframes.md",
            "examples/jump.md",
            "examples/linalg.md",
            "examples/cuda.md",
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

deploydocs(;
    repo = "github.com/el-oso/Mexicah.jl",
    target = "build",
    branch = "gh-pages",
    devbranch = "master",
    push_preview = true,
)
