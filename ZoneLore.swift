import Foundation

struct ZoneLoreData {
    let zoneID: ZoneID
    let ambientText: String
    let historicalEvents: [LoreEvent]
    let zonalNPC: ZoneCharacter
    let zonalProverb: String
}

struct LoreEvent {
    let title: String
    let body: String
    let dayOffset: Int // 0, 1, or 2
}

struct ZoneCharacter {
    let characterID: String // e.g. "npc_askan_watcher"
    let name: String
    let role: String
    let secret: String
}

enum ZoneLore {
    static let all: [ZoneID: ZoneLoreData] = [
        "askan": ZoneLoreData(
            zoneID: "askan",
            ambientText: "Askan luktar gammal betong och regn som aldrig riktigt slutar. Människorna rör sig tyst. Ingen möter din blick — inte av fientlighet, utan av trötthet. Det är ingen hemlighet var botten är. Du står i den.",
            historicalEvents: [
                LoreEvent(title: "Grundandet", body: "Askan bildades inte. Det uppstod. Ingenstans att falla längre.", dayOffset: 0),
                LoreEvent(title: "Den store utrensningen", body: "2041. Fyratusen konton nollades samma natt. Ingen förklaring gavs.", dayOffset: 1),
                LoreEvent(title: "Askans protokoll", body: "Ett enda undantag finns: du kan lämna. Ingen annan hjälp erbjuds.", dayOffset: 2)
            ],
            zonalNPC: ZoneCharacter(characterID: "npc_askan_vagabond", name: "Mara Grå", role: "Tiggare", secret: "Mara hade en gång 400 timmar. Hon vet hur de försvann."),
            zonalProverb: "Tid är den ende tyrann som inte kan bestickas."
        ),
        "spillrorna": ZoneLoreData(
            zoneID: "spillrorna",
            ambientText: "Grundskiftet luktar gammalt kaffe och kopierade papper. Kontorslandskapet sträcker sig i varje riktning. De flesta är nöjda. Det är det skrämmande.",
            historicalEvents: [
                LoreEvent(title: "Skiftets ursprung", body: "Systemet behövde ett mellanlager. Grundskiftet skapades för att fylla det.", dayOffset: 0),
                LoreEvent(title: "Strejken som aldrig hände", body: "2044 planerades en massprotest. Tre deltagare dök upp. De gick hem efter en timme.", dayOffset: 1),
                LoreEvent(title: "Reglerna", body: "Tre regler: Anlända i tid. Lämna i tid. Fråga inte om tid.", dayOffset: 2)
            ],
            zonalNPC: ZoneCharacter(characterID: "npc_grundskiftet_supervisor", name: "Björn Kall", role: "Skiftledare", secret: "Björn rapporterar varje avvikelse. Han vet inte till vem."),
            zonalProverb: "Rutin är frihetens billigaste ersättning."
        ),
        "betongen": ZoneLoreData(
            zoneID: "betongen",
            ambientText: "Krypdalen luktar svett och ambition. De som rör sig här gör det snabbt, med blicken nedåt. Uppför. Alltid uppför. Knäna blöder men stegen fortsätter.",
            historicalEvents: [
                LoreEvent(title: "De krypandes pakt", body: "Ingen hjälper den som redan kryper. Det är zonens enda lag.", dayOffset: 0),
                LoreEvent(title: "Fallet", body: "En spelare nådde Skymring. Tappade allt samma natt. Är tillbaka i Krypdalen. Pratar inte om det.", dayOffset: 1),
                LoreEvent(title: "Vägen", body: "Det finns bara en väg uppåt. Den är smalare än den verkar.", dayOffset: 2)
            ],
            zonalNPC: ZoneCharacter(characterID: "npc_krypdalen_climber", name: "Siv Ek", role: "Klättrare", secret: "Siv har försökt lämna nio gånger. Hon räknar."),
            zonalProverb: "Blöd uppåt. Blöd neråt. Stig aldrig stilla."
        ),
        "dimman": ZoneLoreData(
            zoneID: "dimman",
            ambientText: "Gråbotten är grå. Inte mörk — grå. Kontorister, tekniker, mellanchefer. Alla med exakt tillräckligt med tid. Det är en exakt beräkning. Någon har gjort den åt dem.",
            historicalEvents: [
                LoreEvent(title: "Stabilitetspakten", body: "Gråbotten garanterar inget men tar inget plötsligt. Det räcker för de flesta.", dayOffset: 0),
                LoreEvent(title: "Inflationsminnet", body: "2046 höjdes skiftskatten 12 procent. Ingen protesterade. Tre lämnade.", dayOffset: 1),
                LoreEvent(title: "Komforten", body: "Komfort är ett fängelse utan väggar. De flesta föredrar det.", dayOffset: 2)
            ],
            zonalNPC: ZoneCharacter(characterID: "npc_grabotten_analyst", name: "Per Tyst", role: "Systemanalytiker", secret: "Per vet hur man fuskar systemet. Han gör det inte. Ännu."),
            zonalProverb: "Lagom är precis nog för att stanna kvar."
        ),
        "halvmorkret": ZoneLoreData(
            zoneID: "halvmorkret",
            ambientText: "Skymring lever mellan natt och dag. Halvljuset döljer ansikten men avslöjar rörelser. De som är här ser mörkret men ser också något annat. Möjlighetens silhuett.",
            historicalEvents: [
                LoreEvent(title: "Halvljusets folk", body: "Skymring uppstod när systemet behövde ett gränsland. Det fick ett.", dayOffset: 0),
                LoreEvent(title: "Nattmarknadsryktet", body: "Ryktet säger att Nattmarknaden startade i Skymring. Ryktet är korrekt.", dayOffset: 1),
                LoreEvent(title: "Hoppet", body: "Varje person i Skymring har en plan. De flesta är hemliga. Några fungerar.", dayOffset: 2)
            ],
            zonalNPC: ZoneCharacter(characterID: "npc_skymring_trader", name: "Elsa Gryning", role: "Informationshandlare", secret: "Elsa säljer rykten. Hälften av dem är sanna."),
            zonalProverb: "Skymning är inte slutet. Det är bytet."
        ),
        "granslandet": ZoneLoreData(
            zoneID: "granslandet",
            ambientText: "Halvmörker är tyst på ett sätt som kostar energi. Rummen är mörka. Inte av besparing — av val. De som bor här föredrar det. Kylan är familjär.",
            historicalEvents: [
                LoreEvent(title: "Separationen", body: "Halvmörker separerade sig frivilligt från Skymring 2047. Villkoren är okända.", dayOffset: 0),
                LoreEvent(title: "Nätverket", body: "Det finns ett nätverk i Halvmörker. Det heter ingenting. Det vet du om du behöver veta.", dayOffset: 1),
                LoreEvent(title: "Priset", body: "Allt i Halvmörker har ett pris. Det betalas alltid i tid.", dayOffset: 2)
            ],
            zonalNPC: ZoneCharacter(characterID: "npc_halvmorker_broker", name: "Axel Natt", role: "Mäklare", secret: "Axel mäklar affärer mellan zoner. Tar 15 procent. Alltid."),
            zonalProverb: "Halvmörker är nog mörkt för dem som förtjänar det."
        ),
        "stigarnasdal": ZoneLoreData(
            zoneID: "stigarnasdal",
            ambientText: "Stigarnas Dal är full av korsvägsskyltar. De flesta pekar uppåt men i olika riktningar. Vägarna existerar. Inte alla leder dit du tror.",
            historicalEvents: [
                LoreEvent(title: "Ursprunget", body: "Dalen formades av de som inte visste om de skulle satsa eller spara. De är fortfarande här.", dayOffset: 0),
                LoreEvent(title: "De tre stigarna", body: "Arbete. Spel. Handel. Alla tre är möjliga uppåt. Alla tre är möjliga neråt.", dayOffset: 1),
                LoreEvent(title: "Vägvisarna", body: "Vägvisarna i dalen ger råd mot betalning. Råden är ofta rätt.", dayOffset: 2)
            ],
            zonalNPC: ZoneCharacter(characterID: "npc_stigar_guide", name: "Rut Karta", role: "Vägvisare", secret: "Rut vet vilken stig som är snabbast. Hon säljer den informationen dyrt."),
            zonalProverb: "En väg utan riktning är fortfarande en väg."
        ),
        "uppgangen": ZoneLoreData(
            zoneID: "uppgangen",
            ambientText: "Tröskelzonen är exakt vad namnet antyder. Du är varken inne eller ute. Systemen testar dig hela tiden. Du vet inte om du passerar.",
            historicalEvents: [
                LoreEvent(title: "Tröskeln", body: "Tröskelzonen skapades som ett filter. Inte alla klarar det.", dayOffset: 0),
                LoreEvent(title: "De som fastnat", body: "Vissa spelare lever i Tröskelzonen i månader. De kallar det strategi. Det är det ibland.", dayOffset: 1),
                LoreEvent(title: "Testet", body: "Systemet mäter inte bara balans. Det mäter beteende. Beteendet betygsätts.", dayOffset: 2)
            ],
            zonalNPC: ZoneCharacter(characterID: "npc_troskel_gatekeeper", name: "Ivar Gräns", role: "Gränsvakt", secret: "Ivar har makt att snabba på processer. Han gör det sällan."),
            zonalProverb: "Tröskeln är inte ett hinder. Det är ett val."
        ),
        "troskeln": ZoneLoreData(
            zoneID: "troskeln",
            ambientText: "Duskline är officiellt på rätt sida av gränsen. Inofficiellt vet alla att gränsen kan korsas tillbaka. Det håller alla vakna.",
            historicalEvents: [
                LoreEvent(title: "Uppgraderingen", body: "Duskline var en gång Tröskelzonen. Systemet ritade om kartan. Folk följde efter.", dayOffset: 0),
                LoreEvent(title: "Friheten", body: "I Duskline kan du andas utan att räkna. De flesta räknar ändå.", dayOffset: 1),
                LoreEvent(title: "Risken", body: "Duskline-borna är inte trygga. De är bara tryggare. Skillnaden är viktig.", dayOffset: 2)
            ],
            zonalNPC: ZoneCharacter(characterID: "npc_duskline_mentor", name: "Lena Ljus", role: "Mentor", secret: "Lena hjälper nya Duskline-bor. Hon minns hur det var."),
            zonalProverb: "Frihet smakar annorlunda när man vet vad ofrihet kostar."
        ),
        "klarljuset": ZoneLoreData(
            zoneID: "klarljuset",
            ambientText: "Midgrey är bekvämt. Det är problemet. Bekvämligheten är designad att hålla dig kvar. De flesta märker det men väljer att stanna ändå.",
            historicalEvents: [
                LoreEvent(title: "Mellanskiktet", body: "Midgrey skapades för att absorbera ambitiösa men inte alltför ambitiösa individer.", dayOffset: 0),
                LoreEvent(title: "Lojalitetsprogrammet", body: "Midgrey erbjuder lojalitetsbonus efter 30 dagar. De flesta tar den. De flesta stannar.", dayOffset: 1),
                LoreEvent(title: "Guldet", body: "Det finns verkliga rikedomar i Midgrey. De är precis tillräckliga för att minska hungern att söka mer.", dayOffset: 2)
            ],
            zonalNPC: ZoneCharacter(characterID: "npc_midgrey_comfortable", name: "Nils Nöjd", role: "Pensionär", secret: "Nils hade Aetherpoint i sikte. Valde Midgrey. Ångrar det varje tisdag."),
            zonalProverb: "Bekvämlighet är ambitionens tystaste fiende."
        ),
        "vakttornet": ZoneLoreData(
            zoneID: "vakttornet",
            ambientText: "Risefield luktar potential och förlust i lika delar. De rika och de som snart förlorat allt lever sida vid sida. Ingen vet vem som är vem.",
            historicalEvents: [
                LoreEvent(title: "Marknaden", body: "Risefield byggdes av och för dem som sätter allt på ett kort. Det är ett aktivt val.", dayOffset: 0),
                LoreEvent(title: "Den stora kraschen", body: "2048. Trettio procent av Risefield-populationen föll tillbaka till Gråbotten på en natt.", dayOffset: 1),
                LoreEvent(title: "Spelets regler", body: "I Risefield finns inga regler utöver en: du förlorar vad du inte kan skydda.", dayOffset: 2)
            ],
            zonalNPC: ZoneCharacter(characterID: "npc_risefield_gambler", name: "Finn Odds", role: "Riskanalytiker", secret: "Finn vet odds för varje spel i kasinot. Förlorar ändå."),
            zonalProverb: "Risk är inte farans motsats. Det är dess bränsle."
        ),
        "valvet": ZoneLoreData(
            zoneID: "valvet",
            ambientText: "Aetherpoint är tyst. Inte av tystnad — av kontroll. Varje ljud är avsiktligt. Varje rörelse observeras. Du har nått elitens ingång.",
            historicalEvents: [
                LoreEvent(title: "Grundandet", body: "Aetherpoint skapades av de som bestämde att det behövdes en gräns under dem.", dayOffset: 0),
                LoreEvent(title: "Inspektionerna", body: "Varannan månad inspekteras alla Aetherpoint-konton av systemet. Avvikelser straffas direkt.", dayOffset: 1),
                LoreEvent(title: "Tillträdet", body: "Att nå Aetherpoint är en bedrift. Att stanna kvar kräver mer.", dayOffset: 2)
            ],
            zonalNPC: ZoneCharacter(characterID: "npc_aetherpoint_auditor", name: "Karin Kontroll", role: "Revisor", secret: "Karin genomför inspektionerna. Hon avgör vad som är en avvikelse."),
            zonalProverb: "Eliten definierar inte sin nivå. Den försvarar den."
        ),
        "kronan": ZoneLoreData(
            zoneID: "kronan",
            ambientText: "Novalux lyser men inte för dig. För sig självt. De som lever här tänker inte på Askan — inte för att de glömt, utan för att det inte är relevant längre.",
            historicalEvents: [
                LoreEvent(title: "Ljuset", body: "Novalux namngavs av sin första invånare. Hon sa att det äntligen var ljust nog att se.", dayOffset: 0),
                LoreEvent(title: "Separationen", body: "Novalux avskildes från Aetherpoint när skillnaderna blev för tydliga att ignorera.", dayOffset: 1),
                LoreEvent(title: "Makten", body: "I Novalux betalas skatt frivilligt. Det är ett tecken på att man har råd att vara generös.", dayOffset: 2)
            ],
            zonalNPC: ZoneCharacter(characterID: "npc_novalux_patron", name: "Viktor Ljung", role: "Mecenas", secret: "Viktor finansierar hemligheter. Han väljer noggrant vad som ska förbli hemligt."),
            zonalProverb: "Makt är tyst när den är tillräcklig."
        ),
        "evigheten": ZoneLoreData(
            zoneID: "evigheten",
            ambientText: "Vaultum / Solara är inte en plats. Det är ett tillstånd. Tid är inte en begränsning här — det är ett vapen. Du har nått toppen. Toppen observerar.",
            historicalEvents: [
                LoreEvent(title: "Skaparens val", body: "Vaultum skapades som ett bevis. Att det var möjligt. Det var det.", dayOffset: 0),
                LoreEvent(title: "De ursprungliga", body: "Sju spelare nådde Vaultum det första året. Fyra är kvar. Tre föredrar anonymitet.", dayOffset: 1),
                LoreEvent(title: "Ansvaret", body: "Makten i Vaultum är real. Ansvaret som följer med den är valfritt. Hittills.", dayOffset: 2)
            ],
            zonalNPC: ZoneCharacter(characterID: "npc_vaultum_original", name: "Den Namnlöse Arkitekten", role: "Grundare", secret: "Grundaren skapade Vaultum. Vet hur man förstör det."),
            zonalProverb: "Toppen är inte en plats. Det är ett beslut."
        )
    ]

    static func data(for zoneID: ZoneID) -> ZoneLoreData? {
        all[zoneID]
    }

    // MARK: - Översättning från zonnamn till lore-nyckel

    /// Returnerar rätt nyckel i `all`-ordboken givet ett zonnamn (t.ex. "Stigarnas Dal" → "stigarnasdal").
    static func loreID(forZoneName name: String) -> ZoneID {
        name
            .lowercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "ö", with: "o")
            .replacingOccurrences(of: "ä", with: "a")
            .replacingOccurrences(of: "å", with: "a")
            .folding(options: .diacriticInsensitive, locale: .current)
    }

    // MARK: - Persistence
    static func isUnlocked(zoneID: ZoneID, day: Int) -> Bool {
        UserDefaults.standard.bool(forKey: "loreUnlocked_\(zoneID)_day\(day)")
    }

    static func markUnlocked(zoneID: ZoneID, day: Int) {
        UserDefaults.standard.set(true, forKey: "loreUnlocked_\(zoneID)_day\(day)")
    }
}
