import asyncio,sys
from playwright.async_api import async_playwright
CSS=".reveal{opacity:1!important;transform:none!important}"
async def main():
    W,H=int(sys.argv[1]),int(sys.argv[2])
    async with async_playwright() as p:
        b=await p.chromium.launch(executable_path="/opt/pw-browsers/chromium-1194/chrome-linux/chrome")
        pg=await b.new_page(viewport={"width":W,"height":H},device_scale_factor=1.5)
        await pg.goto("file:///home/user/variant.agencia/checkup/index.html")
        await pg.add_style_tag(content=CSS); await pg.wait_for_timeout(900)
        await pg.screenshot(path="c-hero-%d.png"%W)
        for name,sel in [("c-laudo","#laudo"),("c-corrigir","#corrigir"),("c-planos","#planos")]:
            await pg.evaluate("document.querySelector('%s').scrollIntoView()"%sel)
            await pg.wait_for_timeout(2400)
            await pg.screenshot(path="%s-%d.png"%(name,W))
        print("ok"); await b.close()
asyncio.run(main())
