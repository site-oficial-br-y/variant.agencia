// Tela de carregamento do Bicho Ehn: uma arte aleatória dos personagens, logo, dica e barra.
// Lê o progresso da barra da Godot (que fica escondida) e some quando o jogo abre.
(function () {
	var ARTES = 12;
	var DICAS = [
		"Use os botões de girar pra cair de rodas no chão, e não de cabeça.",
		"Apertar o botão de pular (espaço) solta você do veículo. Às vezes é o que te salva.",
		"Cada personagem tem um especial diferente. Testa todos no menu.",
		"Celular travando? Liga o MODO LEVE no menu.",
		"Cria uma conta no RANKING e seu tempo aparece pra todo mundo.",
		"No JOGAR ONLINE o líder escolhe a fase e todo mundo dá PRONTO.",
		"Setas verdes no chão dão velocidade. Sem embalo você não pula o fogo.",
		"Linha vermelha piscando no poste? Vem arpão. Espera a rajada passar.",
		"Na roda do James, acelera contra o giro quando aparecer SEGURA!",
		"O interruptor verde é o único jeito de machucar o James.",
		"A página caiu no meio do chefão? O menu mostra CONTINUAR.",
		"Tem skin nova na LOJA.",
		"R recomeça a fase na hora.",
		"Decora onde o martelo do Çtamandura vai bater.",
		"Molotov voando: o círculo vermelho no chão mostra onde ele cai."
	];
	var n = 1 + Math.floor(Math.random() * ARTES);
	var dica = Math.floor(Math.random() * DICAS.length);
	var css = "@font-face{font-family:Lilita;src:url(carregando/LilitaOne.woff2) format('woff2');font-display:swap}" +
		"#status{display:none!important}" +
		"#bl{position:fixed;inset:0;z-index:50;background:#0b0612 center/cover no-repeat;font-family:Lilita,system-ui,sans-serif;color:#fff;transition:opacity .5s}" +
		"#bl:after{content:'';position:absolute;inset:0;background:linear-gradient(to top,rgba(5,2,10,.96) 0%,rgba(5,2,10,.75) 22%,rgba(5,2,10,0) 48%)}" +
		"#bl .bx{position:absolute;left:4vw;right:4vw;bottom:5vh;z-index:1;display:flex;align-items:flex-end;gap:3vw}" +
		"#bl img{height:min(17vh,130px);width:auto;filter:drop-shadow(0 4px 12px rgba(0,0,0,.7))}" +
		"#bl .tx{flex:1;min-width:0}" +
		"#bl .dk{font-size:clamp(13px,2.3vw,24px);line-height:1.25;text-shadow:0 2px 6px #000;margin-bottom:1.4vh}" +
		"#bl .dk b{color:#c48bff;letter-spacing:.06em;margin-right:.5em}" +
		"#bl .br{height:12px;border-radius:8px;background:rgba(255,255,255,.14);overflow:hidden;box-shadow:0 0 0 2px rgba(196,139,255,.35)}" +
		"#bl .br i{display:block;height:100%;width:3%;border-radius:8px;background:linear-gradient(90deg,#8a3ffc,#e879f9);transition:width .3s}" +
		"#bl .pc{font-size:clamp(11px,1.6vw,16px);opacity:.7;margin-top:.8vh}";
	var st = document.createElement("style");
	st.textContent = css;
	document.head.appendChild(st);
	var bl = document.createElement("div");
	bl.id = "bl";
	bl.style.backgroundImage = "url(carregando/" + (n < 10 ? "0" : "") + n + ".jpg)";
	bl.innerHTML = '<div class="bx"><img src="carregando/logo.png" alt="Bicho Ehn"><div class="tx">' +
		'<div class="dk"><b>DICA</b><span></span></div><div class="br"><i></i></div><div class="pc">Carregando...</div></div></div>';
	bl.querySelector(".dk span").textContent = DICAS[dica];
	document.body.appendChild(bl);
	var barra = bl.querySelector(".br i");
	var pc = bl.querySelector(".pc");
	var troca = setInterval(function () {               // dica nova a cada 4 s se demorar
		dica = (dica + 1) % DICAS.length;
		bl.querySelector(".dk span").textContent = DICAS[dica];
	}, 4000);
	var t = setInterval(function () {
		var p = document.getElementById("status-progress");
		if (p && p.max > 0 && p.value >= 0) {
			var f = Math.min(1, p.value / p.max);
			barra.style.width = Math.max(3, f * 100) + "%";
			pc.textContent = f < 1 ? "Carregando... " + Math.round(f * 100) + "%" : "Abrindo o jogo...";
		}
		if (!document.getElementById("status")) {      // a Godot tirou a tela dela: o jogo abriu
			clearInterval(t);
			clearInterval(troca);
			barra.style.width = "100%";
			setTimeout(function () { bl.style.opacity = "0"; }, 250);
			setTimeout(function () { bl.remove(); }, 800);
		}
	}, 120);
})();
