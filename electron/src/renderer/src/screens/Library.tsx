import { useMemo, useState } from 'react'
import { t, dyn, type Lang } from '../i18n'
import { daysUntil, resetWord, strengthOf, type Dashboard, type Word } from '../api'
import WordDialog from '../components/WordDialog'

import PendingReview from '../components/PendingReview'

type Props = { dash: Dashboard; lang: Lang; onChanged: () => void }
type Filter = 'all' | 'learning' | 'due' | 'mastered'

function statusOf(word: Word): Exclude<Filter, 'all'> {
  const d = daysUntil(word.next_review_at)
  if (d !== null && d <= 0) return 'due'
  if ((word.repetitions ?? 0) >= 4 && (word.interval ?? 0) > 14) return 'mastered'
  return 'learning'
}

export default function Library({ dash, lang, onChanged }: Props) {
  const [query, setQuery] = useState('')
  const [filter, setFilter] = useState<Filter>('all')
  const [selectedId, setSelectedId] = useState<number | null>(dash.words[0]?.id ?? null)
  const [dialog, setDialog] = useState<'add' | 'edit' | null>(null)
  const [busy, setBusy] = useState(false)

  const rows = useMemo(() => {
    const q = query.trim().toLowerCase()
    return dash.words.filter((w) => {
      if (filter !== 'all' && statusOf(w) !== filter) return false
      if (!q) return true
      return (
        w.word.toLowerCase().includes(q) ||
        (w.meaning ?? '').toLowerCase().includes(q) ||
        (w.reading ?? '').toLowerCase().includes(q)
      )
    })
  }, [dash.words, filter, query])

  const selected = rows.find((w) => w.id === selectedId) ?? rows[0] ?? null

  return (
    <div className="lib">
      <div className="topline">
        <span>
          <b className="pagetitle">{t(lang, 'lib.title')}</b> <span className="muted">{dyn[lang].libCount(dash.totalWords)}</span>
        </span>
      </div>

      <div className="libhead">
        <div className="search">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round">
            <circle cx="11" cy="11" r="7" />
            <path d="M20 20l-3.5-3.5" />
          </svg>
          <input value={query} onChange={(e) => setQuery(e.target.value)} placeholder={t(lang, 'lib.search')} />
          <kbd>Ctrl K</kbd>
        </div>
        <div className="chips">
          {(['all', 'learning', 'due', 'mastered'] as Filter[]).map((f) => (
            <button key={f} className={`chipbtn${filter === f ? ' on' : ''}`} onClick={() => setFilter(f)}>
              {t(lang, `lib.${f}`)}
            </button>
          ))}
        </div>
        <div style={{ flex: 1 }} />
        <button className="btn" onClick={() => setDialog('add')} disabled={!dash.online}>
          {t(lang, 'lib.add')}
        </button>
      </div>

      <div className="libbody">
        <section className="card tablecard">
          <div className="tablewrap">
          <table>
            <colgroup>
              <col style={{ width: '23%' }} />
              <col style={{ width: '29%' }} />
              <col style={{ width: '15%' }} />
              <col style={{ width: '17%' }} />
              <col style={{ width: '16%' }} />
            </colgroup>
            <thead>
              <tr>
                <th>{t(lang, 'col.word')}</th>
                <th>{t(lang, 'col.def')}</th>
                <th>{t(lang, 'col.status')}</th>
                <th>{t(lang, 'col.next')}</th>
                <th>{t(lang, 'col.prof')}</th>
              </tr>
            </thead>
            <tbody>
              {rows.map((w) => {
                const status = statusOf(w)
                const d = daysUntil(w.next_review_at)
                const next = d === null ? '—' : d < 0 ? dyn[lang].dueOverdue : d === 0 ? dyn[lang].dueToday : d === 1 ? dyn[lang].dueTomorrow : dyn[lang].dueIn(d)
                const strength = Math.round(strengthOf(w) * 100)
                return (
                  <tr key={w.id} className={`row${selected?.id === w.id ? ' sel' : ''}`} onClick={() => setSelectedId(w.id)}>
                    <td className="wcell">{w.word}</td>
                    <td>
                      <span className="def">{w.meaning ?? ''}</span>
                    </td>
                    <td>
                      <span className={`st ${status}`}>{t(lang, `st.${status}`)}</span>
                    </td>
                    <td>{next}</td>
                    <td>
                      <div className="prof">
                        <div className="pbar">
                          <i style={{ width: `${strength}%` }} />
                        </div>
                        <span>{strength}%</span>
                      </div>
                    </td>
                  </tr>
                )
              })}
            </tbody>
          </table>
          </div>
          <div className="pager">
            <span>{dyn[lang].pager(rows.length === 0 ? 0 : 1, rows.length, dash.totalWords)}</span>
            <div className="pgs">
              <button>‹</button>
              <button>›</button>
            </div>
          </div>
        </section>

        <PendingReview lang={lang} language={dash.activeLang} onAccepted={onChanged} />

        <aside className="card detail">
          {selected ? (
            <>
              <div className="dhead">
                <div>
                  <div className="word">{selected.word}</div>
                  <div className="phon">
                    {selected.reading ?? ''} {selected.pos ? <span className="pos">{selected.pos}</span> : null}
                  </div>
                </div>
                <span className="play">
                  <svg viewBox="0 0 24 24">
                    <path d="M6 4l10 8-10 8z" fill="currentColor" />
                  </svg>
                </span>
              </div>
              <div className="dsec">
                <div className="dlabel">{t(lang, 'detail.def')}</div>
                <div className="val">{selected.meaning ?? ''}</div>
              </div>
              <div className="dsec">
                <div className="dlabel">{t(lang, 'detail.params')}</div>
                <div className="prow">
                  <span>{t(lang, 'detail.ef')}</span>
                  <b>{(selected.easiness_factor ?? 2.5).toFixed(2)}</b>
                </div>
                <div className="prow">
                  <span>{t(lang, 'detail.interval')}</span>
                  <b>{selected.interval ?? 0}</b>
                </div>
                <div className="prow">
                  <span>{t(lang, 'detail.reps')}</span>
                  <b>{selected.repetitions ?? 0}</b>
                </div>
              </div>
              <div className="dfoot">
                <button className="btn ghost" onClick={() => setDialog('edit')} disabled={!dash.online}>
                  {t(lang, 'lib.edit')}
                </button>
                <button
                  className="btn"
                  disabled={!dash.online || busy}
                  title={dyn[lang].resetHint}
                  onClick={() => {
                    if (!selected || busy) return
                    setBusy(true)
                    void resetWord(selected.id)
                      .then(() => onChanged())
                      .finally(() => setBusy(false))
                  }}
                >
                  {t(lang, 'lib.review')}
                </button>
              </div>
            </>
          ) : (
            <div className="emptystate">{t(lang, 'lib.all')} · —</div>
          )}
        </aside>
      </div>

      {dialog ? (
        <WordDialog
          lang={lang}
          language={dash.activeLang}
          word={dialog === 'edit' ? (selected ?? undefined) : undefined}
          onClose={() => setDialog(null)}
          onSaved={onChanged}
        />
      ) : null}
    </div>
  )
}
