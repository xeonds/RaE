import { defineConfig } from 'vitepress'

export default defineConfig({
  title: 'RaE',
  description: 'awk/jq for binary files — declarative schema and pipeline expressions',
  lang: 'en-US',
  cleanUrls: true,
  lastUpdated: true,
  head: [['link', { rel: 'icon', href: '/favicon.ico' }]],
  themeConfig: {
    nav: [
      { text: 'Guide', link: '/guide/getting-started' },
      { text: 'Reference', link: '/reference/schema' },
      { text: 'Examples', link: '/examples/elf-header' },
    ],
    sidebar: {
      '/guide/': [
        {
          text: 'Introduction',
          items: [
            { text: 'What is RaE?', link: '/guide/what-is-rae' },
            { text: 'Installation', link: '/guide/installation' },
            { text: 'Quick start', link: '/guide/quick-start' },
          ],
        },
        {
          text: 'Core concepts',
          items: [
            { text: 'Modes of operation', link: '/guide/modes' },
            { text: 'Pipeline vs block', link: '/guide/pipeline-block' },
          ],
        },
      ],
      '/reference/': [
        {
          text: 'Schema',
          items: [
            { text: 'Overview', link: '/reference/schema' },
            { text: 'Types', link: '/reference/types' },
            { text: 'Offsets', link: '/reference/offsets' },
            { text: 'Attributes', link: '/reference/attributes' },
            { text: 'Structs & variants', link: '/reference/structs' },
            { text: 'Enums & bitfields', link: '/reference/enums' },
            { text: 'Templates', link: '/reference/templates' },
          ],
        },
        {
          text: 'Expressions',
          items: [
            { text: 'Expressions', link: '/reference/expressions' },
            { text: 'Operators', link: '/reference/operators' },
            { text: 'Built-in functions', link: '/reference/builtins' },
            { text: 'Block & @each', link: '/reference/block' },
          ],
        },
        {
          text: 'CLI',
          items: [
            { text: 'CLI usage', link: '/reference/cli' },
            { text: 'Known limitations', link: '/reference/limitations' },
          ],
        },
      ],
      '/examples/': [
        { text: 'ELF header', link: '/examples/elf-header' },
        { text: 'Mutate + write', link: '/examples/mutate' },
        { text: 'Construct from scratch', link: '/examples/construct' },
        { text: 'Filter with select', link: '/examples/select' },
      ],
    },
    socialLinks: [
      { icon: 'github', link: 'https://github.com/xeonds/RaE' },
    ],
    footer: {
      message: 'Released under the GNU GPL v3',
      copyright: 'Copyright © 2024 xeonds',
    },
  },
})