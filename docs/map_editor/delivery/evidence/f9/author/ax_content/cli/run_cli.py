from pathlib import Path
import subprocess, json, os, hashlib, time
root=Path(__file__).resolve().parents[9]
# Resolve the source explicitly; never pass the code checkout as the Godot project.
root=Path("C:/Users/João Pedro/Documents/ChatGPT/RagRPG/.tools/map-editor-m5")
fixture=root/".godot/verification/e07_f1/fixture_project"
folder=Path(__file__).resolve().parent
engine=Path("C:/Users/João Pedro/Documents/ChatGPT/RagRPG/.tools/godot/Godot_v4.7.2-stable_win64.exe")
head=subprocess.check_output(["git","-C",str(root),"rev-parse","HEAD"],text=True).strip()
env=os.environ.copy(); env["APPDATA"]=str(fixture/".godot/discardable_profile/Roaming"); env["LOCALAPPDATA"]=str(fixture/".godot/discardable_profile/Local")
def action(screen,id,params):return {"screen":screen,"id":id,"parameters":params}
def recipe(destination):
 return [action("piece","piece/document/new",{"document_id":"content_cli","name":"Conteúdo pelo AX","confirm_discard":True}),
 action("terrain","terrain/grid/create",{"layer_id":"floor","name":"Chão","origin_xz":[0,0],"columns":5,"rows":5,"sample_spacing":100,"height":0}),
 action("objects","objects/library/select",{"definition_id":"oak_tree"}),
 action("objects","objects/place",{"placement_id":"tree","definition_id":"oak_tree","surface_id":"floor","position_xz":[100,100],"snap":0}),
 action("objects","objects/place",{"placement_id":"shrub","definition_id":"woodland_shrub","surface_id":"floor","position_xz":[220,200],"snap":0}),
 action("piece","piece/context/rules/set",{"biome_ids":["forest"],"allowed_species":[],"allow_rare":False}),
 action("piece","piece/context/area/upsert",{"region_id":"arena","layer_id":"floor","min_xz":[220,220],"max_xz":[360,360],"allowed_species":[],"allow_rare":False,"reserved":[]}),
 action("piece","piece/socket/upsert",{"socket_id":"entry","surface_id":"floor","position_xyz":[320,0,100],"kind":"entrance"}),
 action("objects","objects/select",{"ids":["tree"]}),action("terrain","terrain/compile_piece",{}),action("objects","objects/library/query",{}),action("piece","piece/document/save",{"path":str(destination)})]
def run(name,actions,native=False):
 request=folder/(name+".request.json");output=folder/(name+".result.json");assert not output.exists()
 request.write_text(json.dumps({"ax_version":1,"actions":actions},ensure_ascii=False,indent=2),encoding="utf-8")
 argv=[str(engine),"--path",str(fixture)]+(["--rendering-method","gl_compatibility"] if native else ["--headless"])+["--script","res://scripts/map_authoring/agent/ax_session.gd","--","--ax-request="+str(request),"--ax-result="+str(output)]
 if native:argv.append("--ax-capture="+str(folder/(name+".png")))
 started=time.monotonic();p=subprocess.run(argv,capture_output=True,text=True,encoding="utf-8",errors="replace",env=env,timeout=300)
 text=p.stdout+p.stderr;(folder/(name+".log")).write_text(text,encoding="utf-8")
 result=json.loads(output.read_text(encoding="utf-8")) if output.exists() else {}
 (folder/(name+".invocation.json")).write_text(json.dumps({"argv":argv,"APPDATA":env["APPDATA"],"LOCALAPPDATA":env["LOCALAPPDATA"],"head":head,"exit_code":p.returncode,"elapsed_seconds":time.monotonic()-started},ensure_ascii=False,indent=2),encoding="utf-8")
 assert p.returncode==0 and result.get("ok") and result["completed_actions"]==len(actions),(name,p.returncode,text[-1200:])
 assert not any(x in text for x in ["SCRIPT ERROR","Parse Error","ERROR:","Unicode parsing error"]),text
 return result
results={}
for mode in ["headless","native"]:
 dest=folder/(mode+".source.json");r=run(mode,recipe(dest),mode=="native")
 compiled=[a["result"]["output_hash"] for a in r["actions"] if a["id"]=="terrain/compile_piece"][0]
 assert r["snapshot"]["source"]["context"]["biome_ids"]==["forest"]
 assert len(r["snapshot"]["source"]["placements"])==2 and r["objects_snapshot"]["selected_ids"]==["tree"]
 results[mode]={"source_hash":r["source_hash"],"compile_hash":compiled,"source_sha256":hashlib.sha256(dest.read_bytes()).hexdigest()}
assert results["headless"]==results["native"],results
reopened=run("reopen",[action("piece","piece/document/open",{"path":str(folder/"native.source.json"),"confirm_discard":True}),action("terrain","terrain/compile_piece",{})])
assert reopened["source_hash"]==results["native"]["source_hash"]
assert subprocess.check_output(["git","-C",str(root),"rev-parse","HEAD"],text=True).strip()==head
(folder/"summary.json").write_text(json.dumps({"ok":True,"head":head,"results":results,"reopen":True},indent=2),encoding="utf-8")
print(json.dumps({"ok":True,"results":results,"reopen":True}))
