from PIL import Image, ImageDraw, ImageFont
import textwrap
import os

OUTPUT_DIR = "/home/user/variant.agencia/espm_study"
os.makedirs(OUTPUT_DIR, exist_ok=True)

W, H = 1080, 1920
ESPM_RED = (180, 20, 20)
DARK = (20, 20, 20)
WHITE = (255, 255, 255)
LIGHT_GRAY = (245, 245, 245)
MID_GRAY = (120, 120, 120)
ACCENT = (230, 60, 60)
CARD_BG = (250, 248, 245)

def get_font(size, bold=False):
    try:
        path = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf" if bold else "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
        return ImageFont.truetype(path, size)
    except:
        return ImageFont.load_default()

def wrap_text(draw, text, font, max_width):
    words = text.split()
    lines = []
    current = ""
    for word in words:
        test = (current + " " + word).strip()
        bbox = draw.textbbox((0,0), test, font=font)
        if bbox[2] > max_width and current:
            lines.append(current)
            current = word
        else:
            current = test
    if current:
        lines.append(current)
    return lines

def draw_rounded_rect(draw, xy, radius, fill):
    x1, y1, x2, y2 = xy
    draw.rectangle([x1+radius, y1, x2-radius, y2], fill=fill)
    draw.rectangle([x1, y1+radius, x2, y2-radius], fill=fill)
    draw.ellipse([x1, y1, x1+2*radius, y1+2*radius], fill=fill)
    draw.ellipse([x2-2*radius, y1, x2, y1+2*radius], fill=fill)
    draw.ellipse([x1, y2-2*radius, x1+2*radius, y2], fill=fill)
    draw.ellipse([x2-2*radius, y2-2*radius, x2, y2], fill=fill)

def draw_text_block(draw, lines, font, color, x, y, line_spacing=8):
    cy = y
    for line in lines:
        draw.text((x, cy), line, font=font, fill=color)
        bbox = draw.textbbox((0,0), line, font=font)
        cy += bbox[3] - bbox[1] + line_spacing
    return cy

def make_card(filename, tag, title, sections):
    img = Image.new("RGB", (W, H), CARD_BG)
    draw = ImageDraw.Draw(img)

    # Header bar
    draw.rectangle([0, 0, W, 140], fill=ESPM_RED)
    # ESPM logo text
    f_espm = get_font(52, bold=True)
    draw.text((50, 30), "ESPM", font=f_espm, fill=WHITE)
    f_sub = get_font(22)
    draw.text((50, 95), "Processo Seletivo 2027.1", font=f_sub, fill=(255,200,200))

    # Tag pill
    f_tag = get_font(26, bold=True)
    tag_bbox = draw.textbbox((0,0), tag, font=f_tag)
    tag_w = tag_bbox[2] + 30
    draw_rounded_rect(draw, [W-60-tag_w, 45, W-40, 95], 20, (255,255,255))
    draw.text((W-50-tag_w+15, 55), tag, font=f_tag, fill=ESPM_RED)

    # Title area
    f_title = get_font(44, bold=True)
    title_lines = wrap_text(draw, title, f_title, W - 100)
    cy = 170
    for line in title_lines:
        draw.text((50, cy), line, font=f_title, fill=DARK)
        bbox = draw.textbbox((0,0), line, font=f_title)
        cy += bbox[3] - bbox[1] + 6

    # Red separator
    cy += 20
    draw.rectangle([50, cy, W-50, cy+5], fill=ESPM_RED)
    cy += 28

    # Sections
    for section in sections:
        sec_type = section.get("type", "block")

        if sec_type == "heading":
            f_h = get_font(34, bold=True)
            draw.text((50, cy), section["text"], font=f_h, fill=ESPM_RED)
            bbox = draw.textbbox((0,0), section["text"], font=f_h)
            cy += bbox[3] - bbox[1] + 14

        elif sec_type == "bullet":
            f_b = get_font(30)
            for item in section["items"]:
                lines = wrap_text(draw, "•  " + item, f_b, W - 130)
                for i, line in enumerate(lines):
                    x_off = 50 if i == 0 else 75
                    draw.text((x_off, cy), line, font=f_b, fill=DARK)
                    bbox = draw.textbbox((0,0), line, font=f_b)
                    cy += bbox[3] - bbox[1] + 6
                cy += 8

        elif sec_type == "highlight_box":
            f_hb = get_font(30, bold=True)
            lines = wrap_text(draw, section["text"], f_hb, W - 160)
            box_h = len(lines) * 48 + 30
            draw_rounded_rect(draw, [50, cy, W-50, cy+box_h], 16, ESPM_RED)
            inner_cy = cy + 18
            for line in lines:
                draw.text((80, inner_cy), line, font=f_hb, fill=WHITE)
                bbox = draw.textbbox((0,0), line, font=f_hb)
                inner_cy += bbox[3] - bbox[1] + 8
            cy += box_h + 20

        elif sec_type == "tip_box":
            f_tip = get_font(28)
            lines = wrap_text(draw, section["text"], f_tip, W - 160)
            box_h = len(lines) * 42 + 30
            draw_rounded_rect(draw, [50, cy, W-50, cy+box_h], 16, (255, 245, 220))
            draw.rectangle([50, cy, 58, cy+box_h], fill=(255,180,0))
            tip_cy = cy + 18
            for line in lines:
                draw.text((80, tip_cy), line, font=f_tip, fill=(80, 60, 0))
                bbox = draw.textbbox((0,0), line, font=f_tip)
                tip_cy += bbox[3] - bbox[1] + 8
            cy += box_h + 20

        elif sec_type == "numbered":
            f_n = get_font(29)
            f_nb = get_font(29, bold=True)
            for i, item in enumerate(section["items"]):
                num = str(i+1)
                # Circle number
                draw_rounded_rect(draw, [50, cy, 86, cy+36], 18, ESPM_RED)
                draw.text((57, cy+4), num, font=get_font(24, bold=True), fill=WHITE)
                lines = wrap_text(draw, item, f_n, W - 150)
                item_cy = cy
                for j, line in enumerate(lines):
                    draw.text((100, item_cy), line, font=f_n, fill=DARK)
                    bbox = draw.textbbox((0,0), line, font=f_n)
                    item_cy += bbox[3] - bbox[1] + 5
                cy = max(cy + 46, item_cy) + 10

        cy += 6

    # Footer
    draw.rectangle([0, H-80, W, H], fill=ESPM_RED)
    f_foot = get_font(26)
    draw.text((50, H-55), "Entrevista — 6 de junho de 2026", font=f_foot, fill=(255,200,200))
    draw.text((W-310, H-55), "Boas respostas! 💪", font=f_foot, fill=WHITE)

    img.save(os.path.join(OUTPUT_DIR, filename))
    print(f"Saved {filename}")

# ─── CARD 0: VISÃO GERAL ──────────────────────────────────────────────────────
make_card("00_visao_geral.png", "GERAL", "Guia Rápido da Entrevista", [
    {"type": "heading", "text": "O que a ESPM quer avaliar"},
    {"type": "bullet", "items": [
        "Capacidade de reflexão crítica (não decorar)",
        "Conexão entre ideias e realidade do curso",
        "Postura ética e visão de impacto social",
        "Articulação verbal e clareza de pensamento",
        "Autoconhecimento e projeto de vida",
    ]},
    {"type": "heading", "text": "5 Questões — mapa rápido"},
    {"type": "numbered", "items": [
        "Transformações mais impactantes hoje",
        "Relação entre inovação e criatividade",
        "Solução inovadora para um desafio do seu curso",
        "Ética e riscos da inovação rápida",
        "Seu plano de desenvolvimento na ESPM",
    ]},
    {"type": "tip_box", "text": "DICA GERAL: Conecte SEMPRE a resposta ao seu curso escolhido. Use exemplos reais. Não existe resposta certa — existe resposta pensada."},
    {"type": "highlight_box", "text": "Tempo médio por questão: 2 a 3 minutos. Seja direto, mostre raciocínio."},
])

# ─── CARD 1 ───────────────────────────────────────────────────────────────────
make_card("01_transformacoes.png", "Q1", "Transformações mais impactantes hoje", [
    {"type": "heading", "text": "O que a questão pede"},
    {"type": "bullet", "items": [
        "Identificar mudanças sociais/tecnológicas relevantes",
        "Conectar essas mudanças às escolhas acadêmicas",
        "Mostrar que você entende o momento histórico",
    ]},
    {"type": "heading", "text": "Transformações-chave para mencionar"},
    {"type": "numbered", "items": [
        "IA generativa: ChatGPT, automação de trabalhos criativos e analíticos",
        "Hiperpersonalização: algoritmos moldam consumo, política e cultura",
        "Mercado de trabalho: novas profissões, trabalho híbrido, freelancing",
        "Desinformação em escala: fake news, bolhas digitais, crise de confiança",
        "Crise climática + ESG: pressão por negócios sustentáveis",
    ]},
    {"type": "heading", "text": "Como conectar ao seu curso"},
    {"type": "tip_box", "text": "Ex. Publicidade: 'A IA muda quem cria e como criamos — preciso entender essas ferramentas sem perder o olhar humano.' / Ex. Administração: 'Decisões de negócio agora dependem de dados e velocidade que antes não existiam.'"},
    {"type": "highlight_box", "text": "Frase de impacto: 'Não basta adaptar o presente — é preciso antecipar o futuro com responsabilidade.'"},
])

# ─── CARD 2 ───────────────────────────────────────────────────────────────────
make_card("02_inovacao_criatividade.png", "Q2", "Inovação vs. Criatividade — qual a relação?", [
    {"type": "heading", "text": "Diferença essencial"},
    {"type": "numbered", "items": [
        "Criatividade = capacidade de gerar ideias novas e originais",
        "Inovação = transformar uma ideia em valor real (social, econômico)",
        "Relação: criatividade é a faísca, inovação é o fogo que aquece",
    ]},
    {"type": "heading", "text": "São inatas ou desenvolvidas?"},
    {"type": "bullet", "items": [
        "Não são apenas dons — são competências cultiváveis",
        "Criatividade cresce com repertório, curiosidade e prática",
        "Inovação exige método, colaboração e contexto",
        "O ambiente (escola, empresa, cultura) facilita ou bloqueia",
    ]},
    {"type": "heading", "text": "Resposta equilibrada sugerida"},
    {"type": "tip_box", "text": "Diga que são as duas coisas: há uma predisposição individual, mas o ambiente e a educação têm papel fundamental. A ESPM existe exatamente para desenvolver esse repertório."},
    {"type": "highlight_box", "text": "'Inovar não é só inventar — é resolver problemas reais de forma relevante para quem vai usar a solução.'"},
])

# ─── CARD 3 ───────────────────────────────────────────────────────────────────
make_card("03_solucao_inovadora.png", "Q3", "Proposta inovadora para o seu curso", [
    {"type": "heading", "text": "Estrutura da resposta (3 partes)"},
    {"type": "numbered", "items": [
        "Desafio: qual problema real você identificou no campo do seu curso?",
        "Proposta: qual solução inovadora você propõe?",
        "Impacto: quais efeitos positivos e possíveis riscos?",
    ]},
    {"type": "heading", "text": "Exemplos por área"},
    {"type": "bullet", "items": [
        "Publicidade/Mkt: plataforma de co-criação entre marcas e comunidades locais usando IA para personalização com curadoria humana",
        "Administração: sistema de gestão que cruza dados ESG com performance financeira em tempo real para PMEs",
        "Design: ferramenta low-code para populações sem acesso a designers profissionais criarem suas próprias identidades visuais",
        "Jornalismo: app que usa IA para detectar desinformação e sugere fontes alternativas ao leitor",
    ]},
    {"type": "tip_box", "text": "IMPORTANTE: Adapte para o seu curso específico! A proposta não precisa ser perfeita — precisa mostrar que você pensa em impacto real."},
    {"type": "highlight_box", "text": "Mencione um impacto positivo E um risco/limite — isso mostra maturidade."},
])

# ─── CARD 4 ───────────────────────────────────────────────────────────────────
make_card("04_etica_riscos.png", "Q4", "Ética e riscos da inovação rápida", [
    {"type": "heading", "text": "Questões éticas essenciais"},
    {"type": "numbered", "items": [
        "Privacidade de dados: quem coleta, o que faz, quem autoriza?",
        "Desigualdade digital: inovação para quem? Exclui quem?",
        "Desinformação e manipulação: IA pode fabricar realidades",
        "Desemprego estrutural: automação sem plano social é crueldade",
        "Viés algorítmico: sistemas reproduzem e amplificam preconceitos",
    ]},
    {"type": "heading", "text": "Como mostrar pensamento ético"},
    {"type": "bullet", "items": [
        "Não demonize a tecnologia — questione o uso dela",
        "Cite responsabilidade de empresas, governos E usuários",
        "Fale em 'inovação responsável' como equilíbrio necessário",
    ]},
    {"type": "tip_box", "text": "Exemplo forte: 'A IA pode ser usada para personalizar ensino ou para vender produtos com manipulação psicológica — a diferença está na escolha de quem a projeta e nos limites que a sociedade impõe.'"},
    {"type": "highlight_box", "text": "'Velocidade sem ética não é progresso — é imprudência com consequências coletivas.'"},
])

# ─── CARD 5 ───────────────────────────────────────────────────────────────────
make_card("05_plano_espm.png", "Q5", "Seu plano de desenvolvimento na ESPM", [
    {"type": "heading", "text": "O que a questão quer saber"},
    {"type": "bullet", "items": [
        "Você se conhece? Tem clareza de pontos fortes e a desenvolver?",
        "Você pesquisou a ESPM? Sabe o que ela oferece?",
        "Você tem intenção genuína — não só um diploma",
        "Você entende seu papel ativo na própria formação",
    ]},
    {"type": "heading", "text": "Estrutura sugerida"},
    {"type": "numbered", "items": [
        "Onde estou: o que já tenho de repertório, experiências, interesses",
        "Onde quero chegar: visão profissional conectada ao contexto atual",
        "Como a ESPM ajuda: projetos práticos, metodologia, networking, interdisciplinaridade",
        "Meu papel: proatividade, curiosidade, colaboração, não esperar passivamente",
    ]},
    {"type": "tip_box", "text": "Pesquise ANTES: mencionar algo específico da ESPM (laboratórios, projetos reais, empresas parceiras, foco em inovação) mostra comprometimento real."},
    {"type": "highlight_box", "text": "'A ESPM não é só um lugar para aprender — é um lugar para experimentar, errar com segurança e construir junto.'"},
])

# ─── CARD 6: FRASES & CONCEITOS ───────────────────────────────────────────────
make_card("06_frases_conceitos.png", "EXTRA", "Frases e conceitos-chave", [
    {"type": "heading", "text": "Conceitos para usar na entrevista"},
    {"type": "bullet", "items": [
        "Pensamento crítico: questionar antes de aceitar",
        "Repertório: base de conhecimento que alimenta criatividade",
        "Impacto social: consequências para além do indivíduo",
        "Inovação responsável: criação com consciência ética",
        "Transformação digital: mudança cultural, não só tecnológica",
        "Colaboração: inovação raramente é solo",
        "Adaptabilidade: competência do século XXI",
    ]},
    {"type": "heading", "text": "Frases de apoio"},
    {"type": "numbered", "items": [
        "'Inovar é propor soluções relevantes para problemas reais.'",
        "'Criatividade sem repertório é só improviso.'",
        "'Tecnologia amplifica tanto o bem quanto o mal — o uso é uma escolha.'",
        "'Educação superior hoje é sobre aprender a aprender continuamente.'",
        "'O mercado não pede só técnica — pede quem pense e se posicione.'",
    ]},
    {"type": "highlight_box", "text": "Use seus próprios exemplos de vida — isso é o que torna a resposta única e genuína."},
])

print("\nTodos os cards gerados em:", OUTPUT_DIR)
