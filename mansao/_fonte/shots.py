import asyncio,sys
from playwright.async_api import async_playwright
CSS=".reveal{opacity:1!important;transform:none!important}"
async def main():
    async with async_playwright() as p:
        b=await p.chromium.launch(executable_path="/opt/pw-browsers/chromium-1194/chrome-linux/chrome")
        pg=await b.new_page(viewport={"width":1440,"height":900},device_scale_factor=1.5)
        await pg.goto("file:///home/user/variant.agencia/mansao/index.html")
        await pg.add_style_tag(content=CSS); await pg.wait_for_timeout(1200)
        for name,sel in [("s1","#casa"),("s2","#galeria"),("s3","#ambientes"),("s4","#local"),("s5","#valor")]:
            await pg.evaluate("document.querySelector('%s').scrollIntoView()"%sel)
            await pg.wait_for_timeout(700)
            await pg.screenshot(path=name+".png")
        print("ok")
        await b.close()
asyncio.run(main())
