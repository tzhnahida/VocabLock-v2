import { t, dyn, typeName, type Lang } from '../i18n'
import type { Dashboard } from '../api'
import PassiveCard from '../components/Passive'

type Props = { dash: Dashboard; lang: Lang }

/**
 * M0 stats screen: the two blocks the design calls for on the home rail
 * (weak points, coverage) promoted to a page. Error-category and AI-disagreement
 * blocks land when the diagnostics panel is ported.
 */
export default function Stats({ dash, lang }: Props) {
  const rows = Object.entries(dash.typeRates)
    .map(([type, rate]) => ({ type, total: rate.total, acc: rate.total > 0 ? rate.correct / rate.total : 0 }))
    .sort((a, b) => a.acc - b.acc)

  return (
    <div className="home">
      <div className="topline">
        <span>
          <b className="pagetitle">{t(lang, 'nav.stats')}</b>
        </span>
        <span>{dash.online ? dyn[lang].online : dyn[lang].offline}</span>
      </div>

      <div className="hgrid">
        <div className="col">
          <section className="card">
            <div className="rh">
              <span>{t(lang, 'rail.weak')}</span>
              <span>{t(lang, 'rail.week')}</span>
            </div>
            <div className="weak">
              {rows.length === 0 ? (
                <div className="emptystate">{dyn[lang].noWeak}</div>
              ) : (
                rows.map((r) => (
                  <div className="wrow" key={r.type}>
                    <div className="wl">
                      <span>{typeName(r.type, lang)}</span>
                      <span>{Math.round(r.acc * 100)}%</span>
                    </div>
                    <div className="wbar">
                      <i style={{ width: `${Math.round(r.acc * 100)}%` }} />
                    </div>
                  </div>
                ))
              )}
            </div>
          </section>
        </div>

        <div className="col">
          <section className="card c-due">
            <div className="rh">
              <span>{t(lang, 'lib.title')}</span>
              <span>{dash.activeLang.toUpperCase()}</span>
            </div>
            <div className="hbig sm">
              <b>{dash.totalWords}</b>
              <span>{t(lang, 'due.unit').replace('词', '')}</span>
            </div>
            <div className="note">{dyn[lang].libCount(dash.pendingReview)}</div>
          </section>
          <section className="card c-streak">
            <div className="rh">
              <span>{t(lang, 'streak.title')}</span>
            </div>
            <div className="hbig sm">
              <b>{dash.streak}</b>
              <span>{t(lang, 'streak.unit')}</span>
            </div>
          </section>
          <PassiveCard lang={lang} />
        </div>
      </div>
    </div>
  )
}
