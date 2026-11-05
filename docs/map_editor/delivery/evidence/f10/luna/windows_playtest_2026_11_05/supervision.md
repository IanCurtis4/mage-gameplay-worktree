# F10 Q5 Windows playtest build — Luna evidence supervision

Date: 2026-11-05  
Build: `C:/Users/João Pedro/Documents/ChatGPT/RagRPG/.tools/playtest_f10/7ac05ff2`  
Runtime source commit: `dc563d2e1c59e949591e1d25a4f5e21f274d3fe4`  
Candidate/docs commit: `7ac05ff2088e31e2164150c6531fe56d55ab671e`  
Engine: Godot 4.7.2 standard; SHA256 `AB1824F85BFD8E0E4128182C000C4003A3E042245B2967848D089B2A04B22424`

Luna performed a read-only review of the prepared build, manifest, logs, probe scripts, profile payload, fixture state, and shortcut. No engine, game, or additional test was launched. The user's Godot Project Manager window, PID 46912, remained running throughout.

## Build identity and artifacts

The build manifest records 2,233 checked source inputs, F1 fixture path `.tools/map-editor-m5/.godot/verification/e07_f1/fixture_project`, main scene `res://scenes/character_menu.tscn`, application name `RagRPG F10 Q5`, and isolated user-data directory `C:\Users\João Pedro\AppData\Roaming\Godot\app_userdata\RagRPG F10 Q5`. Its `fixture_project_restored` and `fixture_preset_restored` flags are true. The manifest's own SHA256 is `DABE701C649C0B36FEDA30B62A5773C7A4FF1CE673111745F32BACEB9B69F16D`; `validation/runs.json` SHA256 is `29B383286293AB47F60AD9E77EBC4B5D54AC3F30588F28D8AED1F5E55EA23A14`.

The fixture `source_hashes.json` has 2,233 entries and SHA256 `993C713950E951CD584D998099FC04CE667B98FAB80420B132FC416748E27DB1`. The checkout HEAD matches the candidate commit in the manifest, and all listed entries matched both checkout and fixture during this read-only check.

| Artifact | Size | SHA256 |
|---|---:|---|
| `RagRPG-F10-Q5.exe` | 109,127,680 B | `4A9EADED8955EF789AB02651ED9D2DDE80328FBB342BD2A6DB4DB33E86305668` |
| `RagRPG-F10-Q5.pck` | 94,861,816 B | `09A10B111B37EA3F9CD0A759AC189A15B3E69EE221820F917DEF99990FACAD41` |

The executable hash matches the M8 release candidate; the PCK is specific to this F10 build and includes the `RagRPG F10 Q5` application identity. Release template SHA256: `D34D36F3BE1A6C49C56525AE86469B92E4F417DDF0B43CF00DD80C385C4B0562`.

## Recorded build and packaged-app checks

The manifest's process records show:

| Run | Exit | Timed out | Result |
|---|---:|---|---|
| `export` | 0 | no | Release export completed. |
| `inspect_pack` | -1 | no | Invalid inspection invocation; no inspection marker was produced. See below. |
| `inspect_pack_editor` | 0 | no | PCK inspection passed. |
| `normal_boot` | 0 | no | Normal executable startup completed with the Compatibility renderer and `--quit-after 120`. |
| `normal_menu_pack` | 0 | no | Packaged menu created and reopened a profile; see payload proof. |

The initial `inspect_pack` attempted to pass `--script` directly to the release executable, which does not support that inspection mode. The owner stopped that attempt; the manifest preserves its `ok=false`, `exit_code=-1`, `timed_out=false` record. This was a harness invocation issue and did not produce product inspection results. The subsequent successful `inspect_pack_editor` mounted the PCK with the standard engine and emitted `F10_PACK_INSPECTION` with `ok=true`, main scene `res://scenes/character_menu.tscn`, app name `RagRPG F10 Q5`, and present character-menu, Forest phase, release registry, and preparation-manifest resources.

The `normal_menu_pack` marker was:

```text
F10_NORMAL_MENU {"character_created":true,"forest_listed":true,"menu_writable":true,"ok":true,"one_character":true,"profile_persisted":true,"profile_reopened":true,"user_data_dir":"C:/Users/João Pedro/Documents/ChatGPT/RagRPG/.tools/playtest_f10/7ac05ff2/validation/normal_menu_pack_profile/Godot/app_userdata/RagRPG F10 Q5"}
```

The saved `profile.json` is 3,990 B, SHA256 `981F379BEEFB864ED6A3C4637A3B452EF7D89C6C9D50A69A1827A6E36DCEB215`; it contains one selected `swordsman` character named `Verificação F10`, with profile revision 1. The probe uses the isolated validation profile inside the build folder; it did not modify the actual AppData save directory. The normal lobby capture is `validation/normal_lobby.png`, 44,531 B, SHA256 `D60EE06BCD5C0697F0AF249CF5588CFD35207D3D14D3AF131BF3A8EF6DAC7BB6`. The parent reports visual inspection confirmed the Forest phase selected and the Start button visible without clipping.

No `SCRIPT ERROR`, `Parse Error`, `ERROR`, or timeout text was found in the export, successful inspection, normal boot, or menu-probe logs. Export did contain a nonfatal warning that the nested project at `tools/map_editor_probe/hosting` would be ignored. The relevant log hashes are:

- Export output: `ABFF0D4D1FA93C9C3F8BEC876FA5043ABBA62845CC74BDFF935D0088725808D6`; engine log: `5F9D909C4D0D1938F4E9A7313C55133A33CE9DB9062F91034B2011EA1E847B60`.
- PCK inspection output: `B75DCD25CD867D99ECD82716F37C998F9E9D7DB0B3EA6735D01874304DFDF736`; engine log: `8F6B19EACAF949B2E6446F5A4BCACD101E47A61830E2660526CA70094F8F03F2`.
- Normal boot output: `AD55AC7ED678FB04A2F1CB60CF55AFCA7C9CE369149523DEBC0A59E05D5659B7`; engine log: `17A53F2D0145D43C68D56528293AC2ACBA9828063453FF5D3819B056FA480DBF`.
- Menu/PCK output: `FE87318ED4F6458153F6390DCB01093E974B07A7198520EF0F7EA3EA8AAD2354`; engine log: `B44E2D0F8D55C3389D605CBC33ABFF0516A125BA8DF879F89AE9FE79A85739F3`.

## Fixture restoration and playtest shortcut

The build manifest says both fixture files were restored. The fixture's current `project.godot` SHA256 is `33726AFE86093A0D6F580114F803045E4F6624DC94528ECBEBD61FB199A06517`; its contents match the source project with the expected F1 VCS-autoload-off delta. The fixture's current `export_presets.cfg` SHA256 is `46ABC20F7D814EFC412C9ED4C6F9AA9BA55D31B4C4A254C14C36262A49751037`. This is intentionally not byte-equal to the main source preset: the imported F1 fixture retains its Git-plugin exclusion and absolute template path. The packaged candidate preset is separately recorded in `validation/packaged_export_presets.cfg` (SHA256 `CDE8A898323CBF9531F292907A2AE97AD25A6F3B653011364F02DE64809A8B87`); it has the console wrapper disabled for release. The fixture's current wrapper setting is restored to 1, rather than left in the packaged release state 0.

The shortcut `C:\Users\João Pedro\Documents\ChatGPT\RagRPG\.tools\playtest_f10\Jogar RagRPG F10.lnk` was read through Windows Shell COM without opening it. Its target is the build's `RagRPG-F10-Q5.exe`, working directory is the build folder, arguments are empty, and icon points to the same executable. Shortcut SHA256: `195054101652C50EB6D7CB3B0D293512AEC2C08D11A7DA62AC91CFA6F718B140`.

## Scope and limits

This confirms the prepared Windows executable/PCK hashes, successful export, packaged-resource lookup, normal boot, and a writable menu/profile round trip with the Forest phase listed. Luna did not open the executable or independently play through the expedition; the gameplay and screenshot checks above are the owner's recorded probes. The invalid `inspect_pack` attempt remains a preserved harness failure; the successful editor-based PCK inspection supersedes it for packaged-resource evidence. This is read-only evidence supervision, not independent semantic audit or human product acceptance.
