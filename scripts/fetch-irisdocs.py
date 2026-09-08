#!/usr/bin/env python3
"""Mirror the official InterSystems documentation for the %Api package into irisdocs/.

    python3 scripts/fetch-irisdocs.py                 # full download + convert
    MODE=convert python3 scripts/fetch-irisdocs.py    # re-convert from irisdocs/html/ without downloading
    EXTRA="%Api.Foo,%Api.Bar" ...                     # force-fetch additional class pages

Sources: docs.intersystems.com (irislatest) DocBook guide pages + Documatic class reference; a class the
website does not publish (e.g. %Api.InteropEditors.v7.*) falls back to the running container's own
Documatic at localhost:52774. Output: irisdocs/guides/*.md, irisdocs/classref/*.md, raw HTML under
irisdocs/html/, and irisdocs/_fetch-report.json. Stdlib only."""
import os, re, sys, time, glob, html, json, base64, urllib.request, urllib.parse
from html.parser import HTMLParser
from datetime import date

ROOT      = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))  # repo root
OUT       = os.path.join(ROOT, "irisdocs")
SITE      = "https://docs.intersystems.com/irislatest/csp"
DOCBOOK   = SITE + "/docbook/DocBook.UI.Page.cls?KEY="
DOCUMATIC = SITE + "/documatic/%25CSP.Documatic.cls?LIBRARY=%25SYS&CLASSNAME="
LOCAL     = "http://localhost:52774/csp/documatic/%25CSP.Documatic.cls?PAGE=CLASS&LIBRARY=%25SYS&CLASSNAME="
UA        = {"User-Agent": "Mozilla/5.0 (OcuPilot docs mirror; contact: repo owner)"}

GUIDES = [  # (KEY, expand child pages?)
  ("GSA_manage_applications", False),
  ("GSCF_ref", False), ("GSCF_tutorial", False),
  ("GCM_rest", False),
  ("GREST", False), ("GREST_intro", False), ("GREST_discover_doc", False),
  ("GREST_reference", True), ("GREST_mgmnt", False),
  ("GDOCDB_rest", False),
  ("D2CLIENT_intro", False), ("D2CLIENT_rest_api", True),
  ("PAGE_apimgr", False),
]

def fetch(url, auth=None, tries=2):
    req = urllib.request.Request(url, headers=dict(UA))
    if auth: req.add_header("Authorization", "Basic " + base64.b64encode(auth.encode()).decode())
    last = None
    for _ in range(tries):
        try:
            with urllib.request.urlopen(req, timeout=90) as r:
                return r.status, r.read().decode("utf-8", "replace")
        except urllib.error.HTTPError as e:
            return e.code, ""
        except Exception as e:
            last = e; time.sleep(2)
    return 0, str(last)

# ---------- HTML -> Markdown (stdlib only) ----------
BLOCK = {"p","div","section","article","h1","h2","h3","h4","h5","h6","ul","ol","li","pre","table","tr",
         "blockquote","dl","dt","dd","hr","br","header","footer","main","nav","aside","figure","figcaption","form"}
SKIP  = {"script","style","nav","noscript","svg","button","input","select","form","iframe","template"}

class MD(HTMLParser):
    def __init__(self, linkmap):
        super().__init__(convert_charrefs=True)
        self.out=[]; self.skipstack=[]; self.pre=0; self.lists=[]; self.href=None; self.linktext=[]
        self.table=None; self.row=None; self.cell=None; self.linkmap=linkmap; self.inhead=False; self.hlevel=0
        self.lasttext=""
    def emit(self, s):
        if self.cell is not None: self.cell.append(s); return
        if self.linktext is not None and self.href is not None: self.linktext.append(s); return
        self.out.append(s)
    def nl(self, n=1):
        cur="".join(self.out[-3:]) if self.cell is None else "".join(self.cell[-3:])
        need=n-(len(cur)-len(cur.rstrip("\n")))
        if need>0: self.emit("\n"*need)
    VOID={"br","img","hr","input","meta","link","area","base","col","embed","source","track","wbr","param"}
    def handle_starttag(self, tag, attrs):
        a=dict(attrs)
        if self.skipstack:
            if tag==self.skipstack[-1][0] and tag not in self.VOID: self.skipstack[-1][1]+=1
            return
        if tag in SKIP or a.get("data-swiftype-index")=="false":
            if tag not in self.VOID: self.skipstack.append([tag,0])
            return
        cls=a.get("class","")
        if tag in ("h1","h2","h3","h4","h5","h6"):
            self.nl(2); self.emit("#"*int(tag[1])+" "); self.hlevel=int(tag[1])
        elif tag=="p": self.nl(2)
        elif tag=="br": self.emit("  \n" if not self.pre else "\n")
        elif tag=="hr": self.nl(2); self.emit("---"); self.nl(2)
        elif tag in ("ul","ol"): self.nl(1); self.lists.append([tag,0])
        elif tag=="li":
            self.nl(1); ind="  "*(len(self.lists)-1)
            if self.lists and self.lists[-1][0]=="ol": self.lists[-1][1]+=1; self.emit(f"{ind}{self.lists[-1][1]}. ")
            else: self.emit(f"{ind}- ")
        elif tag=="pre": self.nl(2); self.emit("```\n"); self.pre+=1
        elif tag=="code" and not self.pre: self.emit("`")
        elif tag in ("b","strong"): self.emit("**")
        elif tag in ("i","em"): self.emit("*")
        elif tag=="blockquote": self.nl(2); self.emit("> ")
        elif tag=="dt": self.nl(1); self.emit("**")
        elif tag=="dd": self.nl(1); self.emit(": ")
        elif tag=="a":
            h=a.get("href","")
            if h and not h.startswith("#") and not h.startswith("javascript"):
                self.href=self._abs(h); self.linktext=[]
        elif tag=="table": self.nl(2); self.table=[]
        elif tag=="tr" and self.table is not None: self.row=[]
        elif tag in ("td","th") and self.row is not None: self.cell=[]
        elif tag=="img":
            alt=a.get("alt","") or "image"; src=a.get("src","")
            self.emit(f"![{alt}]({self._abs(src)})")
    def handle_endtag(self, tag):
        if self.skipstack:
            if tag==self.skipstack[-1][0]:
                if self.skipstack[-1][1]>0: self.skipstack[-1][1]-=1
                else: self.skipstack.pop()
            return
        if tag in ("h1","h2","h3","h4","h5","h6"): self.nl(2)
        elif tag=="p": self.nl(2)
        elif tag in ("ul","ol"):
            if self.lists: self.lists.pop()
            self.nl(2 if not self.lists else 1)
        elif tag=="pre": self.pre-=1; self.nl(1); self.emit("```"); self.nl(2)
        elif tag=="code" and not self.pre: self.emit("`")
        elif tag in ("b","strong"): self.emit("**")
        elif tag in ("i","em"): self.emit("*")
        elif tag=="dt": self.emit("**")
        elif tag=="blockquote": self.nl(2)
        elif tag=="a" and self.href is not None:
            t="".join(self.linktext).strip(); h=self.href; self.href=None; self.linktext=None
            self.emit(f"[{t}]({h})" if t else "")
            self.linktext=[]
        elif tag in ("td","th") and self.cell is not None:
            txt=" ".join("".join(self.cell).split()).replace("|","\\|"); self.row.append(txt); self.cell=None
        elif tag=="tr" and self.row is not None:
            if self.table is not None: self.table.append(self.row)
            self.row=None
        elif tag=="table" and self.table is not None:
            rows=[r for r in self.table if r]; self.table=None
            if rows:
                w=max(len(r) for r in rows)
                rows=[r+[""]*(w-len(r)) for r in rows]
                self.emit("| "+" | ".join(rows[0])+" |\n|"+"|".join([" --- "]*w)+"|\n")
                for r in rows[1:]: self.emit("| "+" | ".join(r)+" |\n")
                self.nl(2)
    def handle_data(self, d):
        if self.skipstack: return
        if self.pre: self.emit(d); return
        t=re.sub(r"\s+"," ",d)
        if t.strip()=="" and (not self.out or self.out[-1].endswith("\n")): return
        if "Opens in a new tab" in t: t=t.replace("Opens in a new tab","")
        self.emit(t)
    def _abs(self, h):
        h=html.unescape(h)
        m=re.match(r"(?:.*DocBook\.UI\.Page\.cls)?\?KEY=([A-Za-z0-9_.-]+)", h)
        if m and m.group(1) in self.linkmap: return self.linkmap[m.group(1)]
        m=re.search(r"CLASSNAME=([^&\"']+)", h)
        if m:
            cn=urllib.parse.unquote(m.group(1))
            if cn in self.linkmap: return self.linkmap[cn]
        if h.startswith("http"): return h
        if "DocBook.UI.Page.cls" in h or "Documatic" in h:
            base=SITE+("/docbook/" if "DocBook" in h else "/documatic/")
            return urllib.parse.urljoin(base, h)
        return urllib.parse.urljoin(SITE+"/docbook/", h)
    def text(self):
        s="".join(self.out)
        s=re.sub(r"[ \t]+\n","\n",s); s=re.sub(r"\n{3,}","\n\n",s)
        return s.strip()+"\n"

def article_of(page):
    """DocBook: <article>…</article>. Documatic: from the first <h1 to the footer."""
    m=re.search(r"<article\b.*?</article>", page, re.S)
    if m: return m.group(0)
    i=page.find('<div class="mainDiv'); 
    if i<0: i=page.lower().find("<h1")
    if i<0: return page
    j=page.find("<footer",i);  j=j if j>0 else len(page)
    return page[i:j]

def to_md(page, title, source, linkmap):
    p=MD(linkmap); p.feed(article_of(page)); body=p.text()
    hdr=f"<!-- source: {source}\n     fetched: {date.today()} — official InterSystems documentation, mirrored for offline reference. Do not edit. -->\n\n"
    if not body.lstrip().startswith("#"): hdr+=f"# {title}\n\n"
    return hdr+body

def save(rel, s):
    p=os.path.join(OUT, rel); os.makedirs(os.path.dirname(p), exist_ok=True)
    with open(p,"w",encoding="utf8") as f: f.write(s)
    return len(s)

# ---------- plan ----------
classes=sorted(os.path.relpath(f, os.path.join(ROOT,"irissys")).replace("/",".")[:-4]
               for f in glob.glob(os.path.join(ROOT,"irissys","%Api","**","*.cls"), recursive=True))
classes=["%Api"]+classes   # package page first
linkmap={}
for k,_ in GUIDES: linkmap[k]=f"../guides/{k}.md"
for c in classes: linkmap[c]=f"../classref/{c}.md"
for k,_ in GUIDES: linkmap.setdefault(k, f"{k}.md")

MODE=os.environ.get("MODE","all"); EXTRA=[c for c in os.environ.get("EXTRA","").split(",") if c]
# generated dispatch classes are not in the source export but are what the web apps name
DISP=["%Api.Mgmnt.v2.disp","%Api.IAM.v1.disp","%Api.InteropMetrics.v1.disp","%Api.InteropEditors.base.dispParent"]+[f"%Api.InteropEditors.v{i}.disp" for i in range(1,8)]
if MODE!="convert": EXTRA=sorted(set(EXTRA)|set(DISP))
else: classes=sorted(set(classes[1:])|set(DISP)); classes=["%Api"]+classes
classes=sorted(set(classes[1:])|set(EXTRA)); classes=["%Api"]+classes
linkmap.update({c:f"../classref/{c}.md" for c in classes})
def load_saved(rel):
    p=os.path.join(OUT,rel)
    return (200, open(p,encoding="utf8").read()) if os.path.exists(p) else (0,"")
report=[]
# ---------- guides ----------
queue=list(GUIDES); seen=set()
while queue:
    key,expand=queue.pop(0)
    if key in seen: continue
    seen.add(key)
    url=DOCBOOK+key; st,page=(load_saved(f"html/guides/{key}.html") if MODE=="convert" else fetch(url))
    if st!=200 or "<article" not in page:
        report.append(("guide",key,st,0,0,"FAILED")); continue
    t=re.search(r"<h1[^>]*>(.*?)</h1>", page, re.S); title=html.unescape(re.sub("<[^>]+>","",t.group(1))).strip() if t else key
    n_html=save(f"html/guides/{key}.html", page)
    lm=dict(linkmap); lm.update({k:f"{k}.md" for k in linkmap if not k.startswith("%")}); lm.update({c:f"../classref/{c}.md" for c in classes})
    n_md=save(f"guides/{key}.md", to_md(page, title, url, lm))
    kids=[]
    if expand:
        art=article_of(page)
        for k in sorted(set(re.findall(r'DocBook\.UI\.Page\.cls\?KEY=([A-Za-z0-9_]+)', art))):
            if k.startswith(key+"_") and k not in seen:
                queue.append((k,False)); kids.append(k); linkmap[k]=f"{k}.md"
    report.append(("guide",key,st,n_html,n_md,title+(f"  (+{len(kids)} child pages)" if kids else "")))
    if MODE!="convert": time.sleep(0.4)

# ---------- class reference ----------
for c in classes:
    if c=="%Api": url=SITE+"/documatic/%25CSP.Documatic.cls?LIBRARY=%25SYS&PACKAGE=%25Api"
    else:         url=DOCUMATIC+urllib.parse.quote(c, safe="")
    if MODE=="convert" and c not in EXTRA: st,page=load_saved(f"html/classref/{c}.html")
    else: st,page=fetch(url)
    src=url; where="web"
    t0=re.search(r"<title>(.*?)</title>", page, re.S); title0=html.unescape(t0.group(1)) if t0 else ""
    ok = st==200 and c in html.unescape(page) and "Item not found" not in title0 and ("InterSystems IRIS" in title0 or title0.strip().startswith("Class "))
    if ok and "InterSystems IRIS" not in title0: where="local-container"; src=LOCAL+c
    if not ok:
        st2,page2=fetch(LOCAL+urllib.parse.quote(c, safe=""), auth="_SYSTEM:SYS")
        if st2==200 and c in html.unescape(page2): page,st,src,where=page2,st2,LOCAL+c,"local-container"
        else: report.append(("class",c,st,0,0,"FAILED (web %s, local %s)"%(st,st2))); continue
    t=re.search(r"<title>(.*?)</title>", page, re.S); title=html.unescape(t.group(1)).strip() if t else c
    lm=dict(linkmap); lm.update({k:f"../guides/{k}.md" for k in linkmap if not k.startswith("%")}); lm.update({cc:f"{cc}.md" for cc in classes})
    n_html=save(f"html/classref/{c}.html", page)
    n_md=save(f"classref/{c}.md", to_md(page, title, src, lm))
    report.append(("class",c,st,n_html,n_md,where))
    time.sleep(0.4)

json.dump(report, open(os.path.join(OUT,"_fetch-report.json"),"w"), indent=1)
# ---------- index ----------
def write_index(report):
    guides=[r for r in report if r[0]=="guide"]; classes=[r for r in report if r[0]=="class"]
    L=["# Official InterSystems documentation for the `%Api` package — offline mirror\n",
       f"Mirrored {date.today()} from **docs.intersystems.com** (`irislatest` = InterSystems IRIS Data Platform 2026.2) by "
       "`scripts/fetch-irisdocs.py`. Each Markdown file starts with a comment giving its source URL. Raw HTML is under "
       "`html/`. **Do not edit** — regenerate with `python3 scripts/fetch-irisdocs.py` (or `MODE=convert …` to re-render "
       "from the saved HTML).\n",
       f"- `guides/` — {len(guides)} DocBook guide pages (the REST-API guides that document what each `%Api.*` dispatch class serves)",
       f"- `classref/` — {len(classes)} Documatic class-reference pages: every `%Api.*` class in the `%SYS` export plus the generated `.disp` dispatch classes\n",
       "Where the website has no page for a class (it lags the installed build), the copy comes from the container's own "
       "Documatic (`http://localhost:52774/csp/documatic/…`, exact for build 221U) and is marked *local-container* below.\n",
       "## Guides (`guides/`)\n\n| Page | Title | Source |\n| --- | --- | --- |"]
    for k,name,st,nh,nm,note in guides:
        title=note.split("  (+")[0]
        L.append(f"| [`{name}.md`](guides/{name}.md) | {title} | [`KEY={name}`](https://docs.intersystems.com/irislatest/csp/docbook/DocBook.UI.Page.cls?KEY={name}) |")
    L.append("\n## Class reference (`classref/`)\n\n| Class | Source |\n| --- | --- |")
    for k,name,st,nh,nm,note in classes:
        q=name.replace("%","%25")
        url=("https://docs.intersystems.com/irislatest/csp/documatic/%25CSP.Documatic.cls?LIBRARY=%25SYS&PACKAGE=%25Api" if name=="%Api"
             else f"https://docs.intersystems.com/irislatest/csp/documatic/%25CSP.Documatic.cls?LIBRARY=%25SYS&CLASSNAME={q}")
        src=f"[docs.intersystems.com]({url})" if note=="web" else "*local-container* (not on the website)"
        L.append(f"| [`{name}`](classref/{name}.md) | {src} |")
    L.append("\n## Which web app → which class → which guide\n\n| Web app | Dispatch class | Guide |\n| --- | --- | --- |")
    for a,b,c in [("/api/atelier","%Api.Atelier (+ .v1…v8)","GSCF_ref, GSCF_tutorial"),("/api/monitor","%Api.Monitor","GCM_rest"),
                  ("/api/mgmnt","%Api.Mgmnt.v2.disp","GREST, GREST_reference (+ per-endpoint pages), GREST_discover_doc, GREST_mgmnt"),
                  ("/api/docdb","%Api.DocDB (+ .v1)","GDOCDB_rest"),("/api/deepsee","%Api.DeepSee","D2CLIENT_rest_api, D2CLIENT_intro"),
                  ("/api/iam","%Api.IAM.v1.disp","PAGE_apimgr"),
                  ("/api/interop-editors","%Api.InteropEditors (+ .v1…v7.disp)","— (class reference only; listed in GSA_manage_applications)"),
                  ("/api/monitor/interop","%Api.InteropMetrics.v1.disp (deprecated class)","GCM_rest"),("/api/iknow","%Api.iKnow (deprecated)","—"),
                  ("all built-in web apps","—","GSA_manage_applications")]:
        L.append(f"| `{a}` | `{b}` | {c} |")
    open(os.path.join(OUT,"README.md"),"w").write("\n".join(L)+"\n")

write_index(report)
print("index written: irisdocs/README.md")

ok=[r for r in report if not r[5].startswith("FAILED")]; bad=[r for r in report if r[5].startswith("FAILED")]
print(f"fetched {len(ok)} pages, {len(bad)} failed")
for r in report: print(f"  {r[0]:<5} {r[1]:<40} HTTP {r[2]:<4} html={r[3]:>7} md={r[4]:>6}  {r[5][:60]}")
