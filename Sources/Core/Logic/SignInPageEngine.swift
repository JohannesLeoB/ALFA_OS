import Foundation

public enum SignInPageEngine {
    public struct Texts: Sendable {
        public let language: String
        public let wordmark: String
        public let title: String
        public let line: String
        public let style: String
        public let openURL: String

        public init(language: String, wordmark: String, title: String, line: String, style: String, openURL: String) {
            self.language = language
            self.wordmark = wordmark
            self.title = title
            self.line = line
            self.style = style
            self.openURL = openURL
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

    private static func markOpen(_ texts: Texts) -> String {
        texts.openURL.isEmpty
            ? "<div class=\"mark\">"
            : "<a class=\"mark\" href=\"\(escape(texts.openURL))\" aria-label=\"\(escape(texts.wordmark))\">"
    }

    private static func render(_ texts: Texts, animated: Bool) -> String {
        let replacements: [(String, String)] = [
            ("{{language}}", escape(texts.language)),
            ("{{wordmark}}", escape(texts.wordmark)),
            ("{{title}}", escape(texts.title)),
            ("{{line}}", escape(texts.line)),
            ("{{style}}", texts.style),
            ("{{markOpen}}", markOpen(texts)),
            ("{{markClose}}", texts.openURL.isEmpty ? "</div>" : "</a>"),
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
    {{style}}
    :root{--scale-mark:2}
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
      font-size:var(--typography-size-body);font-weight:var(--typography-weight-medium);white-space:nowrap;overflow:hidden}
    a.mark{color:var(--c-on-inv);text-decoration:none;cursor:pointer}
    a.mark:focus-visible{outline:var(--size-selectionRingWidth) solid var(--c-ink);outline-offset:var(--size-hairline)}
    .face{flex:none;width:var(--spacing-step28);height:var(--spacing-step28);border-radius:50%;
      border:var(--size-hairline) solid currentColor;
      display:flex;align-items:center;justify-content:center}
    .eyes{display:flex}
    .lids{display:flex;gap:var(--size-blobEyeGap);transform:translateY(var(--size-blobLidOffset)) scaleY(.45)}
    .eyes i{display:block;width:var(--size-blobEyeWidth);height:var(--size-blobEyeHeight);
      border-radius:var(--radius-stroke);background:currentColor}
    .label{font-weight:var(--typography-weight-medium);overflow:hidden;max-width:0;opacity:0;margin-left:0}
    .copy{display:flex;flex-direction:column;align-items:center;gap:var(--spacing-step8);min-height:calc(var(--spacing-step40) + var(--spacing-step24))}
    h1{margin:0;font-size:var(--typography-size-title);font-weight:var(--typography-weight-medium);
      letter-spacing:var(--typography-tracking-title);line-height:var(--typography-lineHeight-title)}
    p{margin:0;color:var(--c-ink-2);font-size:var(--typography-size-body);line-height:var(--typography-lineHeight-body);
      font-weight:var(--typography-weight-regular)}
    body[data-state="accepted"] .mark{animation:enter var(--motion-duration-blobFlight) var(--motion-easing-blobFlight) 200ms both,
      wake var(--motion-duration-blobWidth) var(--motion-easing-standard) 900ms forwards}
    body[data-state="accepted"] .label{animation:label var(--motion-duration-chevron) var(--motion-easing-standard) 980ms forwards,
      labelFade var(--motion-duration-toggle) var(--motion-easing-standard) 1060ms forwards}
    body[data-state="accepted"] .lids{animation:open var(--motion-duration-blobEyes) var(--motion-easing-standard) 900ms forwards,
      blink var(--motion-duration-blobBlinkClose) var(--motion-easing-standard) 1700ms 1}
    body[data-state="unreadable"] .lids{transform:none}
    body[data-state="accepted"] h1{animation:rise var(--motion-duration-overviewEnter) var(--motion-easing-standard) 1900ms both}
    body[data-state="accepted"] p{animation:rise var(--motion-duration-overviewEnter) var(--motion-easing-standard) 2100ms both}
    body[data-state="unreadable"] .label{max-width:200px;opacity:1;margin-left:var(--spacing-step8)}
    body[data-state="unreadable"] .mark{width:var(--size-blobAwakeWidth)}
    @keyframes enter{from{opacity:0;transform:scale(calc(var(--scale-mark) * .92));filter:blur(var(--size-confirmEnterBlur))}
      to{opacity:1;transform:scale(var(--scale-mark));filter:blur(0)}}
    @keyframes wake{from{width:var(--size-blobWidth)}to{width:var(--size-blobAwakeWidth)}}
    @keyframes label{from{max-width:0;margin-left:0}to{max-width:200px;margin-left:var(--spacing-step8)}}
    @keyframes labelFade{from{opacity:0}to{opacity:1}}
    @keyframes open{from{transform:translateY(var(--size-blobLidOffset)) scaleY(.45)}to{transform:none}}
    @keyframes blink{0%,100%{transform:scaleY(1)}50%{transform:scaleY(.1)}}
    @keyframes rise{from{opacity:0;transform:translateY(var(--spacing-step8))}to{opacity:1;transform:none}}
    @media (prefers-reduced-motion:reduce){
      body[data-state] .mark,body[data-state] .label,body[data-state] .lids,body[data-state] h1,body[data-state] p{animation:none}
      body[data-state] .mark{width:var(--size-blobAwakeWidth)}
      body[data-state] .lids{transform:none}
      body[data-state] .label{max-width:200px;opacity:1;margin-left:var(--spacing-step8)}
    }
    </style>
    </head>
    <body data-state="{{state}}">
    <main>
    <div class="stage">
    {{markOpen}}<span class="face"><span class="eyes"><span class="lids"><i></i><i></i></span></span></span><span class="label">{{wordmark}}</span>{{markClose}}
    </div>
    <div class="copy" role="status"><h1>{{title}}</h1><p>{{line}}</p></div>
    </main>
    <script>
    (function(){
      var face=document.querySelector(".face"),eyes=document.querySelector(".eyes");
      if(!face||!eyes)return;
      if(window.matchMedia&&window.matchMedia("(prefers-reduced-motion: reduce)").matches)return;
      var style=getComputedStyle(document.documentElement);
      function token(name){return parseFloat(style.getPropertyValue(name))}
      document.addEventListener("mousemove",function(event){
        var box=face.getBoundingClientRect(),scale=box.width/face.offsetWidth,
          dx=event.clientX-(box.left+box.width/2),dy=event.clientY-(box.top+box.height/2),
          distance=Math.sqrt(dx*dx+dy*dy)/scale,angle=Math.atan2(dy,dx),
          factor=distance<token("--size-blobEyeFollowDistance")?Math.min(1,distance/token("--size-blobEyeFollowRamp")):0;
        eyes.style.transform="translate("+(Math.cos(angle)*token("--size-blobEyeTravelX")*factor).toFixed(2)+"px,"+(Math.sin(angle)*token("--size-blobEyeTravelY")*factor).toFixed(2)+"px)";
      });
    })();
    (function(){
      var mark=document.querySelector("a.mark");
      if(mark)mark.addEventListener("click",function(){window.setTimeout(function(){window.close()},600)});
    })();
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
