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
    case agfa_agfacolor_futura_100_plus
    case agfa_agfacolor_futura_ii_100_plus
    case agfa_agfacolor_futura_ii_200_plus
    case agfa_agfacolor_hdc_100_plus
    case agfa_agfacolor_optima_ii_100
    case agfa_agfacolor_optima_ii_200
    case agfa_agfacolor_vista_050
    case fujifilm_f_125
    case fujifilm_f_250
    case fujifilm_f_400
    case fujifilm_fci
    case fujifilm_fp2900z
    case kodak_dscs_3151
    case kodak_gold_100
    case kodak_gold_200
    case kodak_max_zoom_800
    case kodak_optura_981113
    case kodak_porta_400nc
    case kodak_porta_800
    case kodak_portra_100t
    case kodak_portra_160nc
    
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
