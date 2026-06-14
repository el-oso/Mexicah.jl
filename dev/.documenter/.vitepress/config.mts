import { defineConfig } from 'vitepress'
import { tabsMarkdownPlugin } from 'vitepress-plugin-tabs'
import { mathjaxPlugin } from './mathjax-plugin'
import { juliaReplTransformer } from './julia-repl-transformer'
import footnote from "markdown-it-footnote";
import path from 'path'

const mathjax = mathjaxPlugin()

function getBaseRepository(base: string): string {
  if (!base || base === '/') return '/';
  const parts = base.split('/').filter(Boolean);
  return parts.length > 0 ? `/${parts[0]}/` : '/';
}

const baseTemp = {
  base: '/Mexicah.jl/dev/',// TODO: replace this in makedocs!
}

const navTemp = {
  nav: [
{ text: 'Home', link: '/index' },
{ text: 'Guide', collapsed: false, items: [
{ text: 'Installation', link: '/guide/installation' },
{ text: 'Quickstart', link: '/guide/quickstart' },
{ text: 'Julia Runtime and Shared Libraries', link: '/guide/runtime' },
{ text: 'Comparison with MATFrost.jl', link: '/guide/comparison' }]
 },
{ text: 'Examples', collapsed: false, items: [
{ text: 'Examples', link: '/examples/index' },
{ text: 'Scalar Addition', link: '/examples/scalar' },
{ text: 'Matrix Scaling', link: '/examples/matrix' },
{ text: 'Sparse Matrix: Frobenius Norm', link: '/examples/sparse' },
{ text: 'Automatic Differentiation with Enzyme', link: '/examples/ad_enzyme' },
{ text: 'ModelingToolkit ODE', link: '/examples/mtk_ode' },
{ text: 'Opaque Handle Pattern', link: '/examples/handles' },
{ text: 'DataFrames', link: '/examples/dataframes' },
{ text: 'JuMP Optimization', link: '/examples/jump' },
{ text: 'LinearAlgebra', link: '/examples/linalg' },
{ text: 'GPU kernels (CUDA)', link: '/examples/cuda' }]
 },
{ text: 'Reference', collapsed: false, items: [
{ text: 'API Reference', link: '/reference/api' },
{ text: 'CLI Reference', link: '/reference/cli' },
{ text: 'Type Support and Marshaling', link: '/reference/marshaling' }]
 },
{ text: 'Internals', collapsed: false, items: [
{ text: 'Architecture', link: '/internals/architecture' },
{ text: 'TypeContracts Interfaces', link: '/internals/contracts' }]
 }
]
,
}

const nav = [
  ...navTemp.nav,
  {
    component: 'VersionPicker'
  }
]

// https://vitepress.dev/reference/site-config
export default defineConfig({
  base: '/Mexicah.jl/dev/',// TODO: replace this in makedocs!
  title: 'Mexicah.jl',
  description: 'Documentation for Mexicah.jl',
  lastUpdated: true,
  cleanUrls: true,
  outDir: '../1', // This is required for MarkdownVitepress to work correctly...
  head: [
    
    ['script', {src: `${getBaseRepository(baseTemp.base)}versions.js`}],
    // ['script', {src: '/versions.js'], for custom domains, I guess if deploy_url is available.
    ['script', {src: `${baseTemp.base}siteinfo.js`}]
  ],
  
  markdown: {
    codeTransformers: [juliaReplTransformer()],
    config(md) {
      md.use(tabsMarkdownPlugin);
      md.use(footnote);
      mathjax.markdownConfig(md);
    },
    theme: {
      light: "github-light",
      dark: "github-dark"
    },
  },
  vite: {
    plugins: [
      mathjax.vitePlugin,
    ],
    define: {
      __DEPLOY_ABSPATH__: JSON.stringify('/Mexicah.jl'),
    },
    resolve: {
      alias: {
        '@': path.resolve(__dirname, '../components')
      }
    },
    optimizeDeps: {
      exclude: [ 
        '@nolebase/vitepress-plugin-enhanced-readabilities/client',
        'vitepress',
        '@nolebase/ui',
      ], 
    }, 
    ssr: { 
      noExternal: [ 
        // If there are other packages that need to be processed by Vite, you can add them here.
        '@nolebase/vitepress-plugin-enhanced-readabilities',
        '@nolebase/ui',
      ], 
    },
  },
  themeConfig: {
    outline: 'deep',
    
    search: {
      provider: 'local',
      options: {
        detailedView: true
      }
    },
    nav,
    sidebar: [
{ text: 'Home', link: '/index' },
{ text: 'Guide', collapsed: false, items: [
{ text: 'Installation', link: '/guide/installation' },
{ text: 'Quickstart', link: '/guide/quickstart' },
{ text: 'Julia Runtime and Shared Libraries', link: '/guide/runtime' },
{ text: 'Comparison with MATFrost.jl', link: '/guide/comparison' }]
 },
{ text: 'Examples', collapsed: false, items: [
{ text: 'Examples', link: '/examples/index' },
{ text: 'Scalar Addition', link: '/examples/scalar' },
{ text: 'Matrix Scaling', link: '/examples/matrix' },
{ text: 'Sparse Matrix: Frobenius Norm', link: '/examples/sparse' },
{ text: 'Automatic Differentiation with Enzyme', link: '/examples/ad_enzyme' },
{ text: 'ModelingToolkit ODE', link: '/examples/mtk_ode' },
{ text: 'Opaque Handle Pattern', link: '/examples/handles' },
{ text: 'DataFrames', link: '/examples/dataframes' },
{ text: 'JuMP Optimization', link: '/examples/jump' },
{ text: 'LinearAlgebra', link: '/examples/linalg' },
{ text: 'GPU kernels (CUDA)', link: '/examples/cuda' }]
 },
{ text: 'Reference', collapsed: false, items: [
{ text: 'API Reference', link: '/reference/api' },
{ text: 'CLI Reference', link: '/reference/cli' },
{ text: 'Type Support and Marshaling', link: '/reference/marshaling' }]
 },
{ text: 'Internals', collapsed: false, items: [
{ text: 'Architecture', link: '/internals/architecture' },
{ text: 'TypeContracts Interfaces', link: '/internals/contracts' }]
 }
]
,
    sidebarDrawer: false,
    editLink: { pattern: "https://github.com/el-oso/Mexicah.jl/edit/master/docs/src/:path" },
    socialLinks: [
      { icon: 'github', link: 'https://github.com/el-oso/Mexicah.jl' }
    ],
    footer: {
      message: 'Made with <a href="https://luxdl.github.io/DocumenterVitepress.jl/dev/" target="_blank"><strong>DocumenterVitepress.jl</strong></a><br>',
      copyright: `© Copyright ${new Date().getUTCFullYear()}.`
    }
  }
})
