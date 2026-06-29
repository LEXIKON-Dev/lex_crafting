Locales = {}

Locales['de'] = {
    ['open_workbench'] = '[E] %s öffnen',
    ['no_permission'] = 'Keine Berechtigung.',
    ['config_saved'] = 'Crafting-Konfiguration gespeichert.',
    ['config_saved_detail'] = 'Gespeichert: %s Rezepte, %s Points.',
    ['config_save_failed'] = 'Speichern fehlgeschlagen – Config ungueltig.',
    ['config_save_busy'] = 'Speichern laeuft bereits – bitte warten.',
    ['no_recipes'] = 'Keine Rezepte an diesem Crafting Point.',
    ['too_far'] = 'Du bist zu weit vom Crafting Point entfernt.',
    ['wrong_job'] = 'Dein Job hat keinen Zugang.',
    ['missing_items'] = 'Nicht genug Materialien.',
    ['queue_full'] = 'Warteschlange ist voll.',
    ['craft_started'] = 'Herstellung gestartet.',
    ['craft_failed'] = 'Herstellung fehlgeschlagen.',
    ['craft_success'] = 'Herstellung abgeschlossen – abholen!',
    ['claimed_items'] = 'Items erhalten.',
    ['nothing_to_claim'] = 'Nichts zum Abholen.',
    ['recipe_not_found'] = 'Rezept nicht gefunden.',
    ['point_not_found'] = 'Crafting Point nicht gefunden.',
    ['inventory_full'] = 'Inventar voll.',
}

Locales['en'] = {
    ['open_workbench'] = '[E] Open %s',
    ['no_permission'] = 'No permission.',
    ['config_saved'] = 'Crafting configuration saved.',
    ['config_saved_detail'] = 'Saved: %s recipes, %s points.',
    ['config_save_failed'] = 'Save failed – invalid config.',
    ['config_save_busy'] = 'Save already in progress – please wait.',
    ['no_recipes'] = 'No recipes at this crafting point.',
    ['too_far'] = 'You are too far from the crafting point.',
    ['wrong_job'] = 'Your job does not have access.',
    ['missing_items'] = 'Not enough materials.',
    ['queue_full'] = 'Queue is full.',
    ['craft_started'] = 'Crafting started.',
    ['craft_failed'] = 'Crafting failed.',
    ['craft_success'] = 'Crafting complete – claim your items!',
    ['claimed_items'] = 'Items received.',
    ['nothing_to_claim'] = 'Nothing to claim.',
    ['recipe_not_found'] = 'Recipe not found.',
    ['point_not_found'] = 'Crafting point not found.',
    ['inventory_full'] = 'Inventory full.',
}

function _U(key, ...)
    local locale = Config.Locale or 'de'
    local str = Locales[locale] and Locales[locale][key] or key
    if ... then
        return string.format(str, ...)
    end
    return str
end
