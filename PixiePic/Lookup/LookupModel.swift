//
//  LookupModel.swift
//  PixiePic
//
//  Created by 김주희 on 7/20/24.
//

import Foundation

enum LookupModel: String, CaseIterable {
    case agfa_advantix_100
    case agfa_advantix_200
    case agfa_advantix_400
    case agfa_agfachrome_ct_precisa_100
    case agfa_agfachrome_ct_precisa_200
    case agfa_agfachrome_rsx2_050
    case agfa_agfachrome_rsx2_100
    case agfa_agfachrome_rsx2_200
    case agfa_agfacolor_futura_100_plus
    case agfa_agfacolor_futura_200_plus
    case agfa_agfacolor_futura_400_plus
    case agfa_agfacolor_futura_ii_100_plus
    case agfa_agfacolor_futura_ii_200_plus
    case agfa_agfacolor_futura_ii_400_plus
    case agfa_agfacolor_hdc_100_plus
    case agfa_agfacolor_hdc_200_plus
    case agfa_agfacolor_hdc_400_plus
    case agfa_agfacolor_optima_ii_100
    case agfa_agfacolor_optima_ii_200
    case agfa_agfacolor_vista_050
    case agfa_agfacolor_vista_100
    case agfa_agfacolor_vista_200
    case agfa_agfacolor_vista_400
    case agfa_agfacolor_vista_800
    case fujifilm_f_125
    case fujifilm_f_250
    case fujifilm_f_400
    case fujifilm_fci
    case fujifilm_fp2900z
    case kodak_dscs_3151
    case kodak_dscs_3152
    case kodak_dscs_3153
    case kodak_dscs_3154
    case kodak_dscs_3155
    case kodak_dscs_3156
    case kodak_ektachrome_64
    case kodak_ektachrome_64t
    case kodak_ektachrome_100_plus
    case kodak_ektachrome_100
    case kodak_ektachrome_320t
    case kodak_ektachrome_400x
    case kodak_ektachrome_e100s
    case kodak_gold_100
    case kodak_gold_200
    case kodak_kaf_2001
    case kodak_kaf_3000
    case kodak_kai_0311
    case kodak_kai_0372
    case kodak_kai_1010
    case kodak_kodachrome_25
    case kodak_kodachrome_64
    case kodak_kodachrome_200
    case kodak_max_zoom_800
    case kodak_optura_981111_slrr
    case kodak_optura_981111
    case kodak_optura_981113
    case kodak_optura_981114
    case kodak_porta_400nc
    case kodak_porta_400vc
    case kodak_porta_800
    case kodak_portra_100t
    case kodak_portra_160nc
    case kodak_portra_160vc
    
    init?(filterName: String) {
        self.init(rawValue: filterName)
    }
}

enum LookupModel2: String, CaseIterable {
    // https://giggster.com/guide/free-luts/
    case Undeniable
    case Goingforawalk
    case Goodmorning
    case Nah
    case Onceuponatime
    case Passingby
    case Serenity
    case smoothsailing
    case Urbancowboy
    case wellsee
    case Youcandoit
    // https://www.shutterstock.com/blog/free-luts-for-log-footage
    case BlueArchitecture
    case BlueHour
    case ColdChrome
    case CrispAutumn
    case DarkAndSomber
    case HardBoost
    case LongBeachMorning
    case LushGreen
    case MagicHour
    case NaturalBoost
    case OrangeAndBlue
    case SoftBlackAndWhite
    case Waves
    
    init?(filterName: String) {
        self.init(rawValue: filterName)
    }
}
