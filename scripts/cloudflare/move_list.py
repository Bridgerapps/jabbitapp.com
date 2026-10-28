KEEP_RESEARCH = {
 "amycretin-zenagamtide-weight-loss-phase-3-teardown","amylin-weight-loss-drugs-petrelintide-eloralintide-cagrilintide-teardown",
 "cagrisema-vs-wegovy-zepbound-teardown","cardio-on-ozempic-zepbound-exercise-teardown","compounded-glp1-peptide-powder-supply-chain-teardown",
 "creatine-soft-tissue-injury-cramps-athletes-glp1-evidence-teardown","editorial-standards","efpeglenatide-eppe-korea-approval-vs-wegovy-zepbound-teardown",
 "food-noise-coming-back-ozempic-wegovy-zepbound-retatrutide","foundayo-orforglipron-pill-teardown",
 "glp1-ozempic-wegovy-zepbound-alcohol-drinking-evidence-teardown","glp1-ozempic-wegovy-zepbound-atrial-fibrillation-afib-teardown",
 "glp1-ozempic-wegovy-zepbound-cancer-risk-evidence-teardown","hu6-dnp-prodrug-rivus-fat-burner-evidence-teardown","index",
 "lilly-retatrutide-lawsuits-peptide-sellers-med-spas-teardown","microdosing-ozempic-wegovy-zepbound-mounjaro-low-dose",
 "muscle-loss-ozempic-wegovy-zepbound-lean-mass-creatine","ozempic-face-wegovy-zepbound-facial-fat-loss-teardown",
 "ozempic-vulva-vagina-pelvic-floor-glp1-wegovy-zepbound-teardown","ozempic-wegovy-zepbound-aging-clock-biological-age",
 "ozempic-wegovy-zepbound-before-surgery-anesthesia","ozempic-wegovy-zepbound-bone-loss-osteoporosis-fracture",
 "ozempic-wegovy-zepbound-cagrisema-menopause-hormone-therapy","ozempic-wegovy-zepbound-vision-loss-naion-blindness",
 "ozempic-wegovy-zepbound-weight-loss-plateau-retatrutide-switch","ozempic-zepbound-joy-anhedonia-teardown",
 "retatrutide-biologic-lilly-fda-lawsuit-generics-compounding","retatrutide-peptides-emergency-department-nsw-health",
 "retatrutide-type-2-diabetes-triumph-2-teardown","revita-dmr-weight-regain-after-stopping-zepbound-ozempic-teardown",
 "select-semaglutide-cv-teardown","sources","step-1-semaglutide-teardown","stopping-ozempic-zepbound-weight-regain",
 "surmount-1-tirzepatide-teardown","survodutide-weight-loss-synchronize-teardown","testosterone-trt-men-over-40-traverse-evidence",
 "testosterone-young-men-testmaxxing-fertility-recovery","tradipitant-nereus-ozempic-wegovy-nausea-vomiting-pill-teardown",
 "water-fasting-vs-ozempic-zepbound-muscle-loss-lean-mass-teardown","zepbound-vs-wegovy-tirzepatide-semaglutide-head-to-head-teardown",
}
KEEP_PEPTIDES = {"retatrutide", "semaglutide", "tirzepatide"}
import pathlib
def moved(root="."):
    r = pathlib.Path(root)
    research = sorted(p.stem for p in (r / "research").glob("*.html") if p.stem not in KEEP_RESEARCH)
    peptides = sorted(p.stem for p in (r / "peptides").glob("*.html") if p.stem not in KEEP_PEPTIDES)
    return research, peptides
