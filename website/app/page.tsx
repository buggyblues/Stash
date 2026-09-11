import Link from 'next/link'

type FeatureItem = {
  title: string
  emoji: string
  description: string
}

const features: FeatureItem[] = [
  {
    title: '剪切板历史',
    emoji: '📋',
    description: '自动记录所有复制内容，支持文本、图片、代码、颜色、URL 等类型，随时找回历史记录。',
  },
  {
    title: '智能搜索',
    emoji: '🔍',
    description: '模糊搜索快速定位历史内容，支持按类型、来源应用、标签筛选，键盘全程操作。',
  },
  {
    title: '快捷键召唤',
    emoji: '⚡',
    description: '按 Shift+Cmd+V 即可唤起剪切板面板，不打断工作流，数字键 1-9 快速粘贴。',
  },
  {
    title: '代码高亮预览',
    emoji: '✨',
    description: '使用 VS Code 引擎（Shiki）对代码片段语法高亮，JSON 自动格式化，颜色可视化预览。',
  },
  {
    title: '本地隐私优先',
    emoji: '🛡️',
    description: '所有数据存储在本机 SQLite，不上传任何内容。支持可选的 iCloud Drive 多设备同步。',
  },
]

function FeatureCard({ title, emoji, description }: FeatureItem) {
  return (
    <div className="p-6 rounded-xl border border-neutral-200 dark:border-neutral-800 bg-white dark:bg-neutral-900 hover:-translate-y-1 hover:shadow-lg transition-all duration-200">
      <div className="text-4xl mb-3">{emoji}</div>
      <h3 className="text-base font-semibold mb-2">{title}</h3>
      <p className="text-sm text-neutral-500 dark:text-neutral-400 leading-relaxed">{description}</p>
    </div>
  )
}

export default function Home() {
  return (
    <main>
      {/* Hero */}
      <section className="py-24 px-8 text-center bg-gradient-to-br from-[#1a1a2e] via-[#16213e] to-[#0f3460]">
        <div className="max-w-2xl mx-auto">
          <h1 className="text-6xl font-extrabold mb-4 bg-gradient-to-r from-violet-400 to-blue-400 bg-clip-text text-transparent">
            Z-Paste
          </h1>
          <p className="text-xl text-slate-300 mb-8 leading-relaxed">
            macOS 剪切板管理器
            <br />
            本地存储，隐私优先，免订阅
          </p>
          <div className="flex gap-4 justify-center flex-wrap mb-6">
            <Link
              href="https://github.com/perseveringman/z-paste/releases/latest"
              className="px-6 py-3 rounded-lg bg-violet-600 hover:bg-violet-700 text-white font-semibold transition-colors no-underline"
            >
              免费下载
            </Link>
            <Link
              href="/docs/installation"
              className="px-6 py-3 rounded-lg border border-slate-500 hover:border-slate-300 text-slate-300 hover:text-white font-semibold transition-colors no-underline"
            >
              查看文档
            </Link>
          </div>
          <p className="text-sm text-slate-400">仅支持 macOS · Apple Silicon 和 Intel 均可</p>
        </div>
      </section>

      {/* Features */}
      <section className="py-16 px-8">
        <div className="max-w-5xl mx-auto">
          <h2 className="text-3xl font-bold text-center mb-10">核心功能</h2>
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6">
            {features.map((f) => (
              <FeatureCard key={f.title} {...f} />
            ))}
          </div>
        </div>
      </section>
    </main>
  )
}
