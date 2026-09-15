import sys,asyncio
from playwright.async_api import async_playwright
CSS=".reveal{opacity:1!important;transform:none!important}.grao{display:none}"
async def main():
    W,H=int(sys.argv[1]),int(sys.argv[2]); full=len(sys.argv)>3 and sys.argv[3]=="full"
    async with async_playwright() as p:
        b=await p.chromium.launch(executable_path="/opt/pw-browsers/chromium-1194/chrome-linux/chrome")
        pg=await b.new_page(viewport={"width":W,"height":H},device_scale_factor=2)
        await pg.goto("file:///home/user/variant.agencia/mansao/index.html")
        await pg.add_style_tag(content=CSS)
        await pg.wait_for_timeout(1400)
        name="shot-%d.png"%W
        if full:
            await pg.evaluate("window.scrollTo(0,document.body.scrollHeight)"); await pg.wait_for_timeout(900)
            await pg.evaluate("window.scrollTo(0,0)"); await pg.wait_for_timeout(600)
            await pg.screenshot(path=name,full_page=True)
        else:
            await pg.screenshot(path=name)
        print(name)
        await b.close()
asyncio.run(main())
