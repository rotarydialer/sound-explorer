module ParamOverride
  module_function

  MISSING = :__param_override_missing__

  # Walks `params` along `keys`, returning MISSING if any segment is absent.
  # Accepts either symbol or string keys at every level.
  def get(params, *keys)
    cur = params
    keys.each do |k|
      return MISSING unless cur.is_a?(Hash)
      if cur.key?(k)
        cur = cur[k]
      elsif cur.key?(k.to_s)
        cur = cur[k.to_s]
      elsif k.is_a?(String) && cur.key?(k.to_sym)
        cur = cur[k.to_sym]
      else
        return MISSING
      end
    end
    cur
  end

  # Returns the override value at `keys` or yields for the default.
  def fetch(params, *keys)
    v = get(params, *keys)
    v == MISSING ? yield : v
  end
end
