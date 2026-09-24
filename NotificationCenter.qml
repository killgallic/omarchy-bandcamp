import QtQuick

Item {
    id: root
    visible: false
    property bool autoTick: true
    property var history: []
    property var seenIds: []
    property int serial: 0
    readonly property var toasts: history.filter(item => item.remaining > 0).slice(0, 3)
    readonly property int unresolvedCount: history.filter(item => item.level === 'warning' || item.level === 'error').length
    signal actionRequested(string action)

    function ingestState(patch, previous) {
        for (const key of ['notice', 'error']) {
            if (patch[key] && patch[key] !== previous[key])
                push({level: key === 'error' ? 'error' : 'info', code: 'legacy_' + key, message: String(patch[key])})
        }
        if (patch.error === '') history = history.filter(item => item.code !== 'legacy_error')
    }
    function clear() { history = []; seenIds = []; serial = 0 }
    function safeAction(action) {
        const id = typeof action === 'string' ? action : action && action.id
        return ['retry', 'skip', 'refresh'].indexOf(id) >= 0 ? {id: id, label: id === 'retry' ? 'Retry' : id === 'skip' ? 'Skip' : 'Refresh'} : null
    }
    function push(value) {
        if (!value || typeof value.message !== 'string' || !value.message.trim()) return
        const suppliedId = String(value.id || '')
        if (suppliedId && seenIds.indexOf(suppliedId) >= 0) return
        if (suppliedId) seenIds = [suppliedId].concat(seenIds).slice(0, 80)
        const level = ['success', 'info', 'warning', 'error'].indexOf(value.level) >= 0 ? value.level : 'info'
        const code = String(value.code || '')
        const resource = String(value.resourceId || '')
        const now = Date.now()
        const message = value.message.trim().slice(0, 1000)
        const matching = history.find(item =>
            (code && code.indexOf('legacy_') !== 0 && item.code === code && item.resourceId === resource) ||
            (item.message === message && item.level === level && now - item.updatedAt < 1000))
        const item = {
            id: matching ? matching.id : suppliedId || 'local-' + (++serial),
            level: level, code: code, resourceId: resource, message: message,
            action: safeAction(value.action), count: matching ? matching.count + 1 : 1,
            remaining: level === 'error' || level === 'warning' ? 8000 : 3000,
            paused: matching ? matching.paused : false, updatedAt: now
        }
        history = [item].concat(history.filter(entry => entry.id !== item.id)).slice(0, 20)
    }
    function dismiss(id) { history = history.filter(item => item.id !== id) }
    function resolve(resourceId) {
        if (resourceId) history = history.filter(item => item.resourceId !== resourceId)
    }
    function setPaused(id, paused) {
        const item = history.find(entry => entry.id === id)
        if (item) item.paused = paused
    }
    function activate(id) {
        const item = history.find(entry => entry.id === id)
        if (item && item.action) actionRequested(item.action.id)
    }
    function advance(elapsed) {
        if (!history.some(item => item.remaining > 0 && !item.paused)) return
        let expired = false
        for (const item of history) {
            if (item.remaining <= 0 || item.paused) continue
            item.remaining = Math.max(0, item.remaining - elapsed)
            if (item.remaining === 0) expired = true
        }
        if (expired) history = history.slice()
    }
    Timer { interval: 100; repeat: true; running: root.autoTick && root.toasts.length > 0; onTriggered: root.advance(interval) }
}
