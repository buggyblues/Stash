import { Layout, Navbar, Footer } from 'nextra-theme-docs'
import { getPageMap } from 'nextra/page-map'
import 'nextra-theme-docs/style.css'

export const metadata = {
  title: {
    template: '%s – Stash',
    default: 'Stash 2.0',
  },
  description: 'Stash 2.0 原生 macOS 剪贴板管理器文档',
}

const YEAR = new Date().getFullYear()

export default async function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  const pageMap = await getPageMap()

  return (
    <html lang="zh-CN" suppressHydrationWarning>
      <body>
        <Layout
          pageMap={pageMap}
          docsRepositoryBase="https://github.com/buggyblues/Stash/tree/main/website"
          nextThemes={{
            defaultTheme: 'dark',
          }}
          navbar={
            <Navbar
              logo={<b>Stash</b>}
              projectLink="https://github.com/buggyblues/Stash"
            >
              <a
                href="https://github.com/buggyblues/Stash/releases/latest"
                target="_blank"
                rel="noreferrer"
                style={{ fontWeight: 500 }}
              >
                Download
              </a>
            </Navbar>
          }
          footer={
            <Footer>
              <span>Copyright © {YEAR} Stash</span>
            </Footer>
          }
        >
          {children}
        </Layout>
      </body>
    </html>
  )
}
