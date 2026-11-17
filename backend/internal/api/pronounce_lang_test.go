package api

import (
	"testing"

	"github.com/tzhnahida/VocabLock/internal/config"
)

// A provider that declares its language must not be wired into a different
// course: the julius kit scores Japanese, and wiring it into English would
// return meaningless zeros with no other symptom.
func TestWirePronounceRespectsProviderLanguage(t *testing.T) {
	build := func(providerLang string) *Server {
		en := &config.LanguageConfig{}
		en.Pronounce.Provider = "julius"
		ja := &config.LanguageConfig{}
		ja.Pronounce.Provider = "julius"

		s := &Server{Config: &config.Config{}}
		s.Config.App.ActiveLang = "en"
		s.Config.Languages = map[string]*config.LanguageConfig{"en": en, "ja": ja}
		s.Config.Pronounce.Pronounce.Providers = map[string]config.PronounceProvider{
			"julius": {Lang: providerLang, Binary: "python", Args: []string{"script.py"}},
		}
		return s
	}

	s := build("ja")
	s.WirePronounce()
	if s.PronounceProvider != nil || s.HasPronounce() {
		t.Error("a ja provider was wired into an en course")
	}

	s2 := build("")
	s2.WirePronounce()
	if s2.PronounceProvider == nil {
		t.Error("a provider without a declared language should still wire")
	}

	s3 := build("en-US")
	s3.WirePronounce()
	if s3.PronounceProvider == nil {
		t.Error("an en-US provider should match an en course")
	}
}

func TestBaseLanguageTrimsRegion(t *testing.T) {
	cases := map[string]string{"ja": "ja", "ja-JP": "ja", "zh_CN": "zh", " En ": "en"}
	for in, want := range cases {
		if got := baseLanguage(in); got != want {
			t.Errorf("baseLanguage(%q) = %q, want %q", in, got, want)
		}
	}
}
