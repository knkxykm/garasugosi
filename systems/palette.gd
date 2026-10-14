class_name Palette
## 月雪の体温パレット（原案：真宵家）

const SHINSETSU_WHITE := Color("#E8EBEF")
const GEPPAKU         := Color("#E7E3F0")
const USUFUJI         := Color("#B9AFDF")
const YUKIKAGE_BLUE   := Color("#A9BCD3")
const HOUYOU_SAKURA   := Color("#EFD4CD")
const TSUKIYO_KON     := Color("#2D3E6F")

static func night_bg() -> Color:
	return TSUKIYO_KON.darkened(0.62)
