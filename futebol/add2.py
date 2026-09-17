import json, collections
ARQ='elencos.json'
d=json.load(open(ARQ,encoding='utf-8'))
T={x['id']:x for x in d['times']}
if 'spfc86' in T: print('ja adicionados'); raise SystemExit
for tid in ('san02','cru13','cru14'):
    T[tid].pop('fonte_parcial',None)
T['san02']['fonte']="Santos FC / Imortais — escalação da final do Brasileiro de 2002"

def TM(tid,clube,ano,cores,conq,fonte,el):
    return {"id":tid,"clube":clube,"ano":ano,"cores":cores,"conquista":conq,"fonte":fonte,"elenco":el}
def J(i,n,p,g,o): return {"id":i,"nome":n,"pos":p,"grupo":g,"over":o}

d['times'] += [
 TM("spfc86","São Paulo",1986,["#CC0000","#111111"],"Brasileiro, com Careca e Müller",
   "São Paulo FC — escalação da final do Brasileiro de 1986",[
   J("gilmar-rinaldi","Gilmar","Goleiro","GOL",82), J("fonseca","Fonseca","Lateral-direito","DEF",77),
   J("wagner-basilio","Wágner Basílio","Zagueiro","DEF",78), J("dario-pereyra","Dario Pereyra","Zagueiro","DEF",82),
   J("nelsinho","Nelsinho","Lateral-esquerdo","DEF",78),
   J("bernardo","Bernardo","Volante","MEI",77), J("pita","Pita","Meia","MEI",80),
   J("silas","Silas","Meia","MEI",83), J("muller","Müller","Atacante","ATA",87),
   J("careca","Careca","Centroavante","ATA",90), J("sidnei","Sidnei","Ponta","ATA",77)]),

 TM("gua78","Guarani",1978,["#006B3F","#FFFFFF"],"Brasileiro, o único campeão do interior",
   "Imortais do Futebol / Guarani — escalação da final do Brasileiro de 1978",[
   J("neneca","Neneca","Goleiro","GOL",79), J("mauro-cabecao","Mauro Cabeção","Lateral-direito","DEF",77),
   J("gomes-gua","Gomes","Zagueiro","DEF",77), J("edson-gua","Édson","Zagueiro","DEF",76),
   J("miranda-gua","Miranda","Lateral-esquerdo","DEF",76),
   J("ze-carlos-gua","Zé Carlos","Volante","MEI",78), J("manguinha","Manguinha","Volante","MEI",77),
   J("renato-gua","Renato","Meia","MEI",82), J("capitao","Capitão","Ponta","ATA",78),
   J("careca","Careca","Centroavante","ATA",90), J("bozo","Bozó","Ponta","ATA",78)]),

 TM("cor85","Coritiba",1985,["#00873E","#FFFFFF"],"Brasileiro, o primeiro título do Paraná",
   "Imortais do Futebol / Gazeta do Povo — escalação da final do Brasileiro de 1985",[
   J("rafael-cor","Rafael","Goleiro","GOL",80), J("andre-cor","André","Lateral-direito","DEF",77),
   J("gomes-cor","Gomes","Zagueiro","DEF",77), J("heraldo","Heraldo","Zagueiro","DEF",77),
   J("dida-cor","Dida","Lateral-esquerdo","DEF",78),
   J("almir-cor","Almir","Volante","MEI",77), J("marildo","Marildo","Volante","MEI",77),
   J("tobi","Tóbi","Meia","MEI",79), J("lela","Lela","Ponta","ATA",79),
   J("indio-cor","Índio","Centroavante","ATA",81), J("edson-cor","Édson","Ponta","ATA",78)]),

 TM("spt87","Sport",1987,["#C8102E","#111111"],"Brasileiro",
   "Sport Recife — escalação da final do Brasileiro de 1987",[
   J("flavio-spt","Flávio","Goleiro","GOL",79), J("betao","Betão","Lateral-direito","DEF",77),
   J("estevam","Estevam","Zagueiro","DEF",77), J("marco-antonio-spt","Marco Antônio","Zagueiro","DEF",78),
   J("ze-carlos-macae","Zé Carlos Macaé","Lateral-esquerdo","DEF",77),
   J("rogerio-spt","Rogério","Volante","MEI",77), J("ribamar","Ribamar","Volante","MEI",80),
   J("zico-spt","Zico","Meia","MEI",79), J("robertinho-spt","Robertinho","Ponta","ATA",78),
   J("nando-spt","Nando","Centroavante","ATA",79), J("neco-spt","Neco","Ponta","ATA",78)]),

 TM("bah88","Bahia",1988,["#0057B8","#FFFFFF"],"Brasileiro",
   "Imortais do Futebol / Campeões do Futebol — escalação da final do Brasileiro de 1988",[
   J("ronaldo-bah","Ronaldo","Goleiro","GOL",80), J("tarantini","Tarantini","Lateral-direito","DEF",77),
   J("joao-marcelo","João Marcelo","Zagueiro","DEF",78), J("claudir","Claudir","Zagueiro","DEF",77),
   J("edinho-bah","Edinho","Lateral-esquerdo","DEF",77),
   J("paulo-rodrigues","Paulo Rodrigues","Volante","MEI",78), J("ze-carlos-bah","Zé Carlos","Meia","MEI",79),
   J("bobo","Bobô","Meia","MEI",84), J("osmar-bah","Osmar","Ponta","ATA",77),
   J("charles-bah","Charles","Centroavante","ATA",82), J("marquinhos-bah","Marquinhos","Ponta","ATA",77)]),

 TM("flu84","Fluminense",1984,["#7A1C38","#006437"],"Brasileiro, o time do Casal 20",
   "Fluminense / Imortais do Futebol — time base do Brasileiro de 1984",[
   J("paulo-victor","Paulo Victor","Goleiro","GOL",79), J("aldo-flu","Aldo","Lateral-direito","DEF",77),
   J("duilio","Duílio","Zagueiro","DEF",78), J("ricardo-gomes","Ricardo Gomes","Zagueiro","DEF",83),
   J("branco","Branco","Lateral-esquerdo","DEF",85),
   J("jandir","Jandir","Volante","MEI",77), J("deley","Deley","Volante","MEI",79),
   J("romerito","Romerito","Meia","MEI",86), J("assis","Assis","Meia","MEI",82),
   J("washington-flu","Washington","Centroavante","ATA",80), J("tato","Tato","Atacante","ATA",79)]),

 TM("cap01","Atlético-PR",2001,["#E30613","#111111"],"Brasileiro, o primeiro título do clube",
   "Imortais do Futebol / Campeões do Futebol — time base do Brasileiro de 2001",[
   J("flavio-cap","Flávio","Goleiro","GOL",79), J("gustavo-cap","Gustavo","Zagueiro","DEF",77),
   J("nem","Nem","Zagueiro","DEF",78), J("rogerio-correa","Rogério Corrêa","Zagueiro","DEF",77),
   J("alessandro","Alessandro","Lateral-direito","DEF",79), J("fabiano-cap","Fabiano","Lateral-esquerdo","DEF",78),
   J("cocito","Cocito","Volante","MEI",77), J("kleberson","Kléberson","Volante","MEI",82),
   J("adriano-cap","Adriano","Meia","MEI",79),
   J("kleber-cap","Kléber","Atacante","ATA",81), J("alex-mineiro","Alex Mineiro","Centroavante","ATA",84)]),
]

erros=[]; nomes=collections.defaultdict(set)
for x in d['times']:
    if len(x['elenco'])!=11: erros.append(f"{x['id']}: {len(x['elenco'])}")
    g=collections.Counter(j['grupo'] for j in x['elenco'])
    for k,mn in [('GOL',1),('DEF',3),('MEI',2),('ATA',1)]:
        if g[k]<mn: erros.append(f"{x['id']}: so {g[k]} {k}")
    for k,v in collections.Counter(j['id'] for j in x['elenco']).items():
        if v>1: erros.append(f"{x['id']} repete {k}")
    for j in x['elenco']: nomes[j['id']].add(j['nome'])
for k,v in nomes.items():
    if len(v)>1: erros.append(f"id {k}: {v}")
print('ERROS:', erros if erros else 'nenhum')
if not erros:
    json.dump(d, open(ARQ,'w',encoding='utf-8'), ensure_ascii=False, indent=1)
    hom=collections.defaultdict(set)
    for x in d['times']:
        for j in x['elenco']: hom[j['nome']].add(j['id'])
    print(f"times: {len(d['times'])} | entradas: {sum(len(x['elenco']) for x in d['times'])} | unicos: {len(nomes)}")
    print('todos com fonte:', all(x.get('fonte') for x in d['times']))
    print('parciais:', [x['id'] for x in d['times'] if x.get('fonte_parcial')] or 'nenhum')
    print('homonimos:', sum(1 for v in hom.values() if len(v)>1))
