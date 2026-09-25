//
//  HomeFeedScript.swift
//  UnwatchedShared
//

enum HomeFeedScript {
    static let isReady =
        "location.hostname === 'www.youtube.com' && !!(window.ytcfg && ytcfg.get('INNERTUBE_CONTEXT'))"

    static let isLoggedIn = "ytcfg.get('LOGGED_IN') === true"

    // only the page's HTML: its inline scripts set up `ytcfg`, the rest is YouTube's web app
    static let pageOnlyRules = """
    [
      {"trigger": {"url-filter": ".*", "resource-type": ["script", "style-sheet", "image", "font", \
    "media", "svg-document", "ping", "websocket"]}, "action": {"type": "block"}},
      {"trigger": {"url-filter": ".*", "resource-type": ["document"], "load-context": ["child-frame"]},
       "action": {"type": "block"}}
    ]
    """

    // posts as the page would, with SAPISIDHASH auth when signed in
    static let request = #"""
    const cfg = k => ytcfg.get(k);
    const cookie = name => {
        const match = document.cookie.split('; ').find(c => c.startsWith(name + '='));
        return match ? match.slice(name.length + 1) : null;
    };
    const sha1 = async s => {
        const buf = await crypto.subtle.digest('SHA-1', new TextEncoder().encode(s));
        return [...new Uint8Array(buf)].map(b => b.toString(16).padStart(2, '0')).join('');
    };
    const headers = {
        'Content-Type': 'application/json',
        'X-Youtube-Client-Name': String(cfg('INNERTUBE_CONTEXT_CLIENT_NAME')),
        'X-Youtube-Client-Version': String(cfg('INNERTUBE_CLIENT_VERSION')),
        'X-Origin': location.origin
    };
    if (cfg('VISITOR_DATA')) headers['X-Goog-Visitor-Id'] = cfg('VISITOR_DATA');
    const ts = Math.floor(Date.now() / 1000);
    const auth = [];
    for (const [label, value] of [
        ['SAPISIDHASH', cookie('SAPISID') || cookie('__Secure-3PAPISID')],
        ['SAPISID1PHASH', cookie('__Secure-1PAPISID')],
        ['SAPISID3PHASH', cookie('__Secure-3PAPISID')]
    ]) {
        if (value) auth.push(`${label} ${ts}_${await sha1(`${ts} ${value} ${location.origin}`)}`);
    }
    if (auth.length) {
        headers['Authorization'] = auth.join(' ');
        headers['X-Goog-AuthUser'] = String(cfg('SESSION_INDEX') ?? 0);
    }
    const response = await fetch(`/youtubei/v1/${endpoint}?prettyPrint=false`, {
        method: 'POST',
        credentials: 'include',
        headers,
        body: JSON.stringify(Object.assign({ context: cfg('INNERTUBE_CONTEXT') }, payload))
    });
    if (!response.ok) return { status: response.status, body: null };
    // the search parser would read a mix or playlist lockup as its first video
    const prune = o => {
        if (Array.isArray(o)) return o.filter(x => !(x && x.lockupViewModel && x.lockupViewModel.contentType !== 'LOCKUP_CONTENT_TYPE_VIDEO')).map(prune);
        if (o && typeof o === 'object') { for (const k in o) o[k] = prune(o[k]); }
        return o;
    };
    return { status: response.status, body: JSON.stringify(prune(await response.json())) };
    """#
}
