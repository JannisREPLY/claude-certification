import { Children, useEffect, useRef } from 'react'
import Markdown from 'react-markdown'
import remarkGfm from 'remark-gfm'
import rehypeHighlight from 'rehype-highlight'

export const slug = (text) => 'sec-' + String(text).toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '')

const textOf = (children) => Children.toArray(children).map((c) => (typeof c === 'string' ? c : textOf(c.props?.children))).join('')
const heading = (Tag) => ({ children }) => <Tag id={slug(textOf(children))}>{children}</Tag>
const components = { h2: heading('h2'), h3: heading('h3') }

export function headingSlug(md) {
  return slug(md.replace(/[`*]/g, ''))
}

export default function LessonBody({ markdown, focus }) {
  const ref = useRef(null)
  useEffect(() => {
    if (!focus) return
    const el = ref.current?.querySelector(`#${CSS.escape(headingSlug(focus))}`)
    if (el) {
      el.scrollIntoView({ block: 'start' })
      el.classList.add('focus')
    }
  }, [focus, markdown])
  return (
    <div className="md" ref={ref}>
      <Markdown remarkPlugins={[remarkGfm]} rehypePlugins={[rehypeHighlight]} components={components}>{markdown}</Markdown>
    </div>
  )
}
