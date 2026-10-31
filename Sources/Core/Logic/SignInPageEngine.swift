import Foundation

public enum SignInPageEngine {
    public struct Texts: Sendable {
        public let language: String
        public let wordmark: String
        public let title: String
        public let line: String

        public init(language: String, wordmark: String, title: String, line: String) {
            self.language = language
            self.wordmark = wordmark
            self.title = title
            self.line = line
        }
    }

    public static func acceptedPage(_ texts: Texts) -> String {
        render(texts, animated: true)
    }

    public static func unreadablePage(_ texts: Texts) -> String {
        render(texts, animated: false)
    }

    static func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    private static func render(_ texts: Texts, animated: Bool) -> String {
        let replacements: [(String, String)] = [
            ("{{language}}", escape(texts.language)),
            ("{{wordmark}}", escape(texts.wordmark)),
            ("{{title}}", escape(texts.title)),
            ("{{line}}", escape(texts.line)),
            ("{{state}}", animated ? "accepted" : "unreadable"),
        ]
        return replacements.reduce(template) { $0.replacingOccurrences(of: $1.0, with: $1.1) }
    }

    private static let template = #"""
    <!DOCTYPE html>
    <html lang="{{language}}">
    <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta name="color-scheme" content="light dark">
    <title>{{wordmark}} · {{title}}</title>
    <style>
    :root{
      --c-ground:#ffffff;--c-ink:#171717;--c-ink-2:#4d4d4d;--c-inv:#171717;--c-on-inv:#ffffff;
      --sh-float:0 0 0 1px rgba(0,0,0,.08),0 8px 24px rgba(0,0,0,.10);
      --size-blobHeight:40px;--size-blobWidth:56px;--size-blobAwakeWidth:124px;--size-blobEyeWidth:4px;
      --size-blobEyeHeight:8px;--size-blobEyeGap:4px;--size-hairline:1px;--size-confirmEnterBlur:3px;
      --radius-blob:20px;--radius-stroke:2px;--spacing-step8:8px;--spacing-step16:16px;--spacing-step24:24px;
      --spacing-step28:28px;--spacing-step40:40px;--spacing-blobInset:6px;
      --typography-family-text:Geist,"SF Pro Text",system-ui,-apple-system,sans-serif;
      --typography-size-small:11.5px;--typography-size-body:13px;--typography-size-title:18px;
      --typography-weight-regular:400;--typography-weight-medium:500;
      --typography-tracking-title:-0.02em;--typography-lineHeight-title:1.25;--typography-lineHeight-body:1.35;
      --opacity-ringOnMark:.22;--motion-easing-standard:cubic-bezier(0.2,0.8,0.2,1);
      --motion-easing-blobFlight:cubic-bezier(0.2,1.15,0.3,1);
      --motion-duration-blobFlight:416ms;--motion-duration-blobWidth:240ms;--motion-duration-blobBlinkClose:140ms;
      --motion-duration-toggle:200ms;--motion-duration-chevron:240ms;--motion-duration-overviewEnter:640ms;
      --motion-duration-labelDelay:80ms;--scale-mark:2;
    }
    @media (prefers-color-scheme:dark){
      :root{
        --c-ground:#0d0d0d;--c-ink:#fafafa;--c-ink-2:#d9d9d9;--c-inv:#2e2e2e;--c-on-inv:#fafafa;
        --sh-float:0 0 0 1px rgba(255,255,255,.10),0 8px 24px rgba(0,0,0,.5);
      }
    }
    *{box-sizing:border-box}
    html,body{height:100%;margin:0}
    body{background:var(--c-ground);color:var(--c-ink);font-family:var(--typography-family-text);
      display:flex;align-items:center;justify-content:center;overflow:hidden;
      -webkit-font-smoothing:antialiased}
    main{display:flex;flex-direction:column;align-items:center;gap:var(--spacing-step24);padding:var(--spacing-step24);
      text-align:center}
    .stage{width:calc(var(--size-blobAwakeWidth) * var(--scale-mark));height:calc(var(--size-blobHeight) * var(--scale-mark));
      display:flex;align-items:center;justify-content:center}
    .mark{flex:none;width:var(--size-blobWidth);height:var(--size-blobHeight);display:flex;align-items:center;
      padding:0 var(--spacing-blobInset);background:var(--c-inv);color:var(--c-on-inv);border-radius:var(--radius-blob);
      box-shadow:var(--sh-float);transform:scale(var(--scale-mark));transform-origin:center;
      font-size:var(--typography-size-small);font-weight:var(--typography-weight-medium);white-space:nowrap;overflow:hidden}
    .face{flex:none;width:var(--spacing-step28);height:var(--spacing-step28);border-radius:50%;
      border:var(--size-hairline) solid color-mix(in srgb,currentColor calc(var(--opacity-ringOnMark) * 100%),transparent);
      display:flex;align-items:center;justify-content:center}
    .eyes{display:flex;gap:var(--size-blobEyeGap);transform-origin:center}
    .eyes i{display:block;width:var(--size-blobEyeWidth);height:var(--size-blobEyeHeight);
      border-radius:var(--radius-stroke);background:currentColor}
    .label{overflow:hidden;max-width:0;opacity:0;margin-left:0}
    .copy{display:flex;flex-direction:column;align-items:center;gap:var(--spacing-step8);min-height:calc(var(--spacing-step40) + var(--spacing-step24))}
    h1{margin:0;font-size:var(--typography-size-title);font-weight:var(--typography-weight-medium);
      letter-spacing:var(--typography-tracking-title);line-height:var(--typography-lineHeight-title)}
    p{margin:0;color:var(--c-ink-2);font-size:var(--typography-size-body);line-height:var(--typography-lineHeight-body);
      font-weight:var(--typography-weight-regular)}
    body[data-state="accepted"] .mark{animation:enter var(--motion-duration-blobFlight) var(--motion-easing-blobFlight) 200ms both,
      wake var(--motion-duration-blobWidth) var(--motion-easing-standard) 900ms forwards}
    body[data-state="accepted"] .label{animation:label var(--motion-duration-chevron) var(--motion-easing-standard) 980ms forwards,
      labelFade var(--motion-duration-toggle) var(--motion-easing-standard) 1060ms forwards}
    body[data-state="accepted"] .eyes{animation:blink var(--motion-duration-blobBlinkClose) var(--motion-easing-standard) 1700ms 1}
    body[data-state="accepted"] h1{animation:rise var(--motion-duration-overviewEnter) var(--motion-easing-standard) 1900ms both}
    body[data-state="accepted"] p{animation:rise var(--motion-duration-overviewEnter) var(--motion-easing-standard) 2100ms both}
    body[data-state="unreadable"] .label{max-width:96px;opacity:1;margin-left:var(--spacing-step8)}
    body[data-state="unreadable"] .mark{width:var(--size-blobAwakeWidth)}
    @keyframes enter{from{opacity:0;transform:scale(calc(var(--scale-mark) * .92));filter:blur(var(--size-confirmEnterBlur))}
      to{opacity:1;transform:scale(var(--scale-mark));filter:blur(0)}}
    @keyframes wake{from{width:var(--size-blobWidth)}to{width:var(--size-blobAwakeWidth)}}
    @keyframes label{from{max-width:0;margin-left:0}to{max-width:96px;margin-left:var(--spacing-step8)}}
    @keyframes labelFade{from{opacity:0}to{opacity:1}}
    @keyframes blink{0%,100%{transform:scaleY(1)}50%{transform:scaleY(.12)}}
    @keyframes rise{from{opacity:0;transform:translateY(var(--spacing-step8))}to{opacity:1;transform:none}}
    @media (prefers-reduced-motion:reduce){
      body[data-state] .mark,body[data-state] .label,body[data-state] .eyes,body[data-state] h1,body[data-state] p{animation:none}
      body[data-state] .mark{width:var(--size-blobAwakeWidth)}
      body[data-state] .label{max-width:96px;opacity:1;margin-left:var(--spacing-step8)}
    }
    </style>
    </head>
    <body data-state="{{state}}">
    <main>
    <div class="stage" aria-hidden="true">
    <div class="mark"><span class="face"><span class="eyes"><i></i><i></i></span></span><span class="label">{{wordmark}}</span></div>
    </div>
    <div class="copy" role="status"><h1>{{title}}</h1><p>{{line}}</p></div>
    </main>
    <script>
    (function(){
      if(document.body.dataset.state!=="accepted")return;
      if(window.matchMedia&&window.matchMedia("(prefers-reduced-motion: reduce)").matches)return;
      var Context=window.AudioContext||window.webkitAudioContext;
      if(!Context)return;
      var context;
      try{context=new Context()}catch(error){return}
      if(context.state!=="running"){try{context.close()}catch(error){}return}
      function note(frequency,start,length){
        var oscillator=context.createOscillator(),gain=context.createGain(),at=context.currentTime+start;
        oscillator.type="sine";oscillator.frequency.value=frequency;
        gain.gain.setValueAtTime(0,at);gain.gain.linearRampToValueAtTime(.05,at+.04);
        gain.gain.exponentialRampToValueAtTime(.0001,at+length);
        oscillator.connect(gain);gain.connect(context.destination);
        oscillator.start(at);oscillator.stop(at+length+.05);
      }
      note(392,.2,1.4);note(587.33,.38,1.6);
    })();
    </script>
    </body>
    </html>
    """#
}
