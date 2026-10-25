#!/usr/bin/env python3
"""Read-only ECAD import acceptance in an isolated browser-local TEST company.
Serve build/web on localhost:8297, then pass a LibreECAD material JSON path.
"""
import json, os, re, sys
from pathlib import Path
from playwright.sync_api import sync_playwright, expect, TimeoutError as PlaywrightTimeout
source=Path(sys.argv[1] if len(sys.argv)>1 else 'test/fixtures/libre_ecad_material.json').resolve()
packet=json.loads(source.read_text()); errors=[]
with sync_playwright() as p:
    browser=p.chromium.launch(headless=True)
    page=browser.new_page(viewport={'width':1600,'height':1300});page.set_default_timeout(20000)
    page.on('pageerror',lambda e:errors.append(str(e)))
    page.goto(os.environ.get('ERP_PREVIEW_URL','http://127.0.0.1:8297'))
    try:
        page.wait_for_load_state('networkidle',timeout=10000)
    except PlaywrightTimeout:
        # Drift's long-lived worker keeps Chromium's aggregate load state busy.
        # Require the real application's actionable controls below instead.
        pass
    page.locator('flt-semantics-placeholder').evaluate('(e)=>e.click()')
    def button(name):return page.get_by_role('button',name=name,exact=True)
    def field(label,value):
        f=page.get_by_role('textbox',name=label,exact=True);f.click();page.wait_for_timeout(100);f.press('ControlOrMeta+A');f.press('Backspace');f.press_sequentially(value,delay=3)
    def inspect(name):
        page.wait_for_timeout(400);Path('/tmp/werkkern-m7-'+name+'.txt').write_text(page.locator('body').aria_snapshot());page.screenshot(path='/tmp/werkkern-m7-'+name+'.png')
    button('Firma anlegen').click();field('Firmenname','TEST LibreECAD Import');button('Anlegen').click()
    inspect('home')
    if os.environ.get('ERP_HOME'):raise SystemExit(0)
    # Existing wide shell omits sidebar items from Flutter web semantics.
    # Coordinate comes from the inspected 1600x1300 TEST-company screenshot.
    page.mouse.click(80,294)
    button('Artikel anlegen').click();field('Name *','TEST ERP Ziel');button('Anlegen').click()
    button('LibreECAD-Materialvorschau').click()
    def load():
        with page.expect_file_chooser() as chooser:button('LibreECAD-Datei öffnen').click()
        chooser.value.set_files(str(source));page.wait_for_timeout(700)
    load();inspect('import')
    if os.environ.get('ERP_INSPECT'):raise SystemExit(0)
    assert packet['projectName'] in page.locator('body').aria_snapshot()
    page.get_by_role('button',name=re.compile('Bestehenden ERP-Artikel ausdrücklich zuordnen Offen lassen$')).first.click()
    page.get_by_role('menuitem',name=re.compile('^TEST ERP Ziel')).click()
    load()
    expect(page.get_by_role('button',name=re.compile('Bestehenden ERP-Artikel ausdrücklich zuordnen Offen lassen$'))).to_have_count(len(packet['items']))
    button('Zuordnungsentwurf exportieren').click()
    with page.expect_download() as download:button('Entwurf exportieren').click()
    download.value.save_as('/tmp/werkkern-m7-import-preview.json')
    result=json.loads(Path('/tmp/werkkern-m7-import-preview.json').read_text())
    assert result['packetId']==packet['packetId'] and result['mappings']=={} and result['status']=='preview'
    inspect('reloaded')
    assert not errors,errors
    browser.close()
    print('PASS ERP browser: actual LibreECAD JSON, explicit mapping, repeat-load reset, draft download; isolated browser storage only')
