import json, collections
ARQ='elencos.json'
d=json.load(open(ARQ,encoding='utf-8'))
T={x['id']:x for x in d['times']}
if 'bot62' in T:
    print('ja adicionados; nada a fazer'); raise SystemExit

T['gre83']['elenco']=[
 {"id":"mazaropi","nome":"Mazaropi","pos":"Goleiro","grupo":"GOL","over":83},
 {"id":"paulo-roberto-gre","nome":"Paulo Roberto","pos":"Lateral-direito","grupo":"DEF","over":77},
 {"id":"baidek","nome":"Baidek","pos":"Zagueiro","grupo":"DEF","over":78},
 {"id":"de-leon","nome":"De León","pos":"Zagueiro","grupo":"DEF","over":87},
 {"id":"pc-magalhaes","nome":"P.C. Magalhães","pos":"Lateral-esquerdo","grupo":"DEF","over":77},
 {"id":"china","nome":"China","pos":"Volante","grupo":"MEI","over":78},
 {"id":"osvaldo-gre","nome":"Osvaldo","pos":"Volante","grupo":"MEI","over":77},
 {"id":"pc-lima","nome":"P.C. Lima","pos":"Meia","grupo":"MEI","over":77},
 {"id":"mario-sergio","nome":"Mário Sérgio","pos":"Meia","grupo":"MEI","over":81},
 {"id":"renato-gaucho","nome":"Renato Gaúcho","pos":"Ponta","grupo":"ATA","over":89},
 {"id":"tarciso","nome":"Tarciso","pos":"Ponta","grupo":"ATA","over":79}]
T['gre83']['fonte']="Goal — escalação da final do Mundial de 1983"

T['cru03']['elenco']=[
 {"id":"gomes","nome":"Gomes","pos":"Goleiro","grupo":"GOL","over":85},
 {"id":"maurinho-cru","nome":"Maurinho","pos":"Lateral-direito","grupo":"DEF","over":77},
 {"id":"cris","nome":"Cris","pos":"Zagueiro","grupo":"DEF","over":85},
 {"id":"edu-dracena","nome":"Edu Dracena","pos":"Zagueiro","grupo":"DEF","over":81},
 {"id":"leandro-cru","nome":"Leandro","pos":"Lateral-esquerdo","grupo":"DEF","over":76},
 {"id":"maldonado","nome":"Maldonado","pos":"Volante","grupo":"MEI","over":80},
 {"id":"augusto-recife","nome":"Augusto Recife","pos":"Volante","grupo":"MEI","over":78},
 {"id":"wendell-cru","nome":"Wendell","pos":"Meia","grupo":"MEI","over":78},
 {"id":"alex-cru","nome":"Alex","pos":"Meia","grupo":"MEI","over":92},
 {"id":"aristizabal","nome":"Aristizábal","pos":"Centroavante","grupo":"ATA","over":83},
 {"id":"deivid","nome":"Deivid","pos":"Centroavante","grupo":"ATA","over":84}]
T['cru03']['fonte']="Imortais do Futebol — Cruzeiro 2003"

def T_(tid,clube,ano,cores,conq,fonte,el):
    return {"id":tid,"clube":clube,"ano":ano,"cores":cores,"conquista":conq,"fonte":fonte,"elenco":el}
def J(i,n,pos,g,o): return {"id":i,"nome":n,"pos":pos,"grupo":g,"over":o}

d['times'] += [
 T_("bot62","Botafogo",1962,["#111111","#FFFFFF"],"Carioca e Rio-São Paulo, o time de Garrincha",
   "Imortais do Futebol / Mundo Botafogo — time base de 1962",[
   J("manga","Manga","Goleiro","GOL",85), J("paulistinha","Paulistinha","Lateral-direito","DEF",77),
   J("tome","Tomé","Zagueiro","DEF",77), J("ze-maria-bot","Zé Maria","Zagueiro","DEF",78),
   J("nilton-santos","Nilton Santos","Lateral-esquerdo","DEF",91),
   J("airton-bot","Airton","Volante","MEI",77), J("pampolini","Pampolini","Volante","MEI",76),
   J("didi","Didi","Meia","MEI",92), J("garrincha","Garrincha","Ponta-direita","ATA",97),
   J("quarentinha","Quarentinha","Centroavante","ATA",84), J("zagallo","Zagallo","Ponta-esquerda","ATA",85)]),

 T_("vas98","Vasco",1998,["#111111","#FFFFFF"],"Libertadores",
   "Goal — escalação da final da Libertadores de 1998",[
   J("carlos-germano","Carlos Germano","Goleiro","GOL",83), J("vagner-vas","Vágner","Lateral-direito","DEF",77),
   J("odvan","Odvan","Zagueiro","DEF",79), J("mauro-galvao","Mauro Galvão","Zagueiro","DEF",83),
   J("felipe-vas","Felipe","Lateral-esquerdo","DEF",84),
   J("luisinho-vas","Luisinho","Volante","MEI",77), J("nasa","Nasa","Volante","MEI",78),
   J("juninho-pernambucano","Juninho Pernambucano","Meia","MEI",88), J("pedrinho-vas","Pedrinho","Meia","MEI",81),
   J("donizete","Donizete Pantera","Atacante","ATA",82), J("luizao","Luizão","Centroavante","ATA",83)]),

 T_("cor83","Corinthians",1983,["#111111","#FFFFFF"],"Paulista, o time da Democracia Corintiana",
   "Imortais do Futebol — Corinthians 1982-1984",[
   J("solito","Solito","Goleiro","GOL",78), J("alfinete","Alfinete","Lateral-direito","DEF",77),
   J("mauro-cor","Mauro","Zagueiro","DEF",78), J("juninho-cor","Juninho","Zagueiro","DEF",76),
   J("wladimir","Wladimir","Lateral-esquerdo","DEF",82),
   J("zenon","Zenon","Meia","MEI",81), J("paulinho-cor83","Paulinho","Volante","MEI",77),
   J("biro-biro","Biro-Biro","Meia","MEI",81), J("socrates","Sócrates","Meia","MEI",93),
   J("ataliba","Ataliba","Atacante","ATA",78), J("casagrande","Casagrande","Centroavante","ATA",85)]),

 T_("int76","Internacional",1976,["#CC0000","#FFFFFF"],"Bicampeão Brasileiro",
   "Internacional / Imortais do Futebol — time base de 1976",[
   J("manga","Manga","Goleiro","GOL",85), J("claudio-int","Cláudio","Lateral-direito","DEF",77),
   J("figueroa","Figueroa","Zagueiro","DEF",89), J("herminio","Hermínio","Zagueiro","DEF",77),
   J("vacaria","Vacaria","Lateral-esquerdo","DEF",77),
   J("carpegiani","Paulo César Carpegiani","Volante","MEI",84), J("cacapava","Caçapava","Volante","MEI",79),
   J("falcao","Falcão","Meia","MEI",92), J("valdomiro","Valdomiro","Ponta-direita","ATA",83),
   J("flavio-int","Flávio","Centroavante","ATA",80), J("lula-int","Lula","Ponta-esquerda","ATA",78)]),

 T_("cru66","Cruzeiro",1966,["#003C82","#FFFFFF"],"Taça Brasil, batendo o Santos de Pelé na final",
   "Cruzeiropédia / O Tempo — escalação da final da Taça Brasil",[
   J("raul-cru","Raul","Goleiro","GOL",82), J("pedro-paulo","Pedro Paulo","Lateral-direito","DEF",77),
   J("william-cru","William","Zagueiro","DEF",78), J("procopio","Procópio","Zagueiro","DEF",77),
   J("neco","Neco","Lateral-esquerdo","DEF",76),
   J("piazza","Piazza","Volante","MEI",85), J("dirceu-lopes","Dirceu Lopes","Meia","MEI",88),
   J("tostao","Tostão","Meia-atacante","MEI",94), J("natal","Natal","Ponta-direita","ATA",79),
   J("evaldo","Evaldo","Centroavante","ATA",79), J("hilton-oliveira","Hilton Oliveira","Ponta-esquerda","ATA",78)]),

 T_("pal73","Palmeiras",1973,["#006437","#FFFFFF"],"Brasileiro, a Segunda Academia",
   "Palmeiras / Imortais do Futebol — a Segunda Academia",[
   J("leao","Leão","Goleiro","GOL",89), J("eurico","Eurico","Lateral-direito","DEF",77),
   J("luis-pereira","Luís Pereira","Zagueiro","DEF",86), J("alfredo-pal","Alfredo","Zagueiro","DEF",78),
   J("zeca-pal","Zeca","Lateral-esquerdo","DEF",77),
   J("dudu-pal73","Dudu","Volante","MEI",83), J("ademir-da-guia","Ademir da Guia","Meia","MEI",92),
   J("edu-pal","Edu","Ponta-esquerda","ATA",81), J("leivinha","Leivinha","Atacante","ATA",84),
   J("cesar-pal","César","Centroavante","ATA",82), J("nei-pal","Nei","Ponta-direita","ATA",78)]),

 T_("cor98","Corinthians",1998,["#111111","#FFFFFF"],"Bicampeão Brasileiro",
   "Imortais do Futebol — Corinthians 1998-2000",[
   J("nei-cor","Nei","Goleiro","GOL",79), J("indio-cor","Índio","Lateral-direito","DEF",77),
   J("batata","Batata","Zagueiro","DEF",77), J("gamarra","Gamarra","Zagueiro","DEF",84),
   J("sylvinho","Sylvinho","Lateral-esquerdo","DEF",82),
   J("vampeta","Vampeta","Volante","MEI",83), J("rincon","Rincón","Volante","MEI",85),
   J("marcelinho-carioca","Marcelinho Carioca","Meia","MEI",87), J("ricardinho-cor","Ricardinho","Meia","MEI",82),
   J("edilson-cor","Edílson","Atacante","ATA",84), J("didi-cor","Didi","Centroavante","ATA",78)]),

 T_("gre17","Grêmio",2017,["#0D80BF","#111111"],"Libertadores",
   "Wikipédia / ogol — escalação da final da Libertadores de 2017",[
   J("grohe","Marcelo Grohe","Goleiro","GOL",84), J("edilson-gre","Edílson","Lateral-direito","DEF",78),
   J("geromel","Geromel","Zagueiro","DEF",85), J("kannemann","Kannemann","Zagueiro","DEF",82),
   J("bruno-cortez","Bruno Cortez","Lateral-esquerdo","DEF",78),
   J("jailson-gre","Jailson","Volante","MEI",79), J("arthur","Arthur","Volante","MEI",85),
   J("ramiro","Ramiro","Meia","MEI",79), J("fernandinho-gre","Fernandinho","Ponta","MEI",80),
   J("luan-gre","Luan","Atacante","ATA",87), J("cicero","Cícero","Atacante","ATA",79)]),

 T_("spfc07","São Paulo",2007,["#CC0000","#111111"],"Penta Brasileiro, com recorde de defesa",
   "São Paulo FC — escalação do título de 2007",[
   J("rogerio-ceni","Rogério Ceni","Goleiro","GOL",91), J("andre-dias","André Dias","Zagueiro","DEF",78),
   J("miranda","Miranda","Zagueiro","DEF",85), J("breno","Breno","Zagueiro","DEF",77),
   J("junior-spfc","Júnior","Lateral-esquerdo","DEF",80),
   J("hernanes","Hernanes","Meia","MEI",85), J("richarlyson","Richarlyson","Volante","MEI",78),
   J("jorge-wagner","Jorge Wagner","Meia","MEI",80), J("leandro-spfc","Leandro","Meia","MEI",77),
   J("aloisio","Aloísio","Atacante","ATA",79), J("dagoberto","Dagoberto","Centroavante","ATA",80)]),

 T_("bot95","Botafogo",1995,["#111111","#FFFFFF"],"Brasileiro, com Túlio artilheiro",
   "Goal — escalação da final do Brasileiro de 1995",[
   J("wagner-bot","Wágner","Goleiro","GOL",78), J("wilson-goiano","Wilson Goiano","Lateral-direito","DEF",76),
   J("wilson-gottardo","Wilson Gottardo","Zagueiro","DEF",79), J("goncalves","Gonçalves","Zagueiro","DEF",81),
   J("andre-silva-bot","André Silva","Lateral-esquerdo","DEF",76),
   J("leandro-bot","Leandro","Volante","MEI",77), J("jamir","Jamir","Volante","MEI",77),
   J("beto-bot","Beto","Meia","MEI",78), J("sergio-manoel","Sérgio Manoel","Meia","MEI",78),
   J("donizete","Donizete Pantera","Atacante","ATA",82), J("tulio","Túlio","Centroavante","ATA",88)]),
]

erros=[]; nomes=collections.defaultdict(set)
for x in d['times']:
    if len(x['elenco'])!=11: erros.append(f"{x['id']}: {len(x['elenco'])} jogadores")
    g=collections.Counter(j['grupo'] for j in x['elenco'])
    for k,mn in [('GOL',1),('DEF',3),('MEI',2),('ATA',1)]:
        if g[k]<mn: erros.append(f"{x['id']}: so {g[k]} {k}")
    for k,v in collections.Counter(j['id'] for j in x['elenco']).items():
        if v>1: erros.append(f"{x['id']} repete {k}")
    for j in x['elenco']: nomes[j['id']].add(j['nome'])
for k,v in nomes.items():
    if len(v)>1: erros.append(f"id {k} com nomes diferentes: {v}")
print('ERROS:', erros if erros else 'nenhum')
if not erros:
    json.dump(d, open(ARQ,'w',encoding='utf-8'), ensure_ascii=False, indent=1)
    print('times:',len(d['times']),'| entradas:',sum(len(x['elenco']) for x in d['times']),'| jogadores unicos:',len(nomes))
    print('com fonte:',sum(1 for x in d['times'] if x.get('fonte')))
