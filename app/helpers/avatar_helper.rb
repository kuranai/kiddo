module AvatarHelper
  def user_avatar(user, size_class: "w-10", text_size_class: "text-sm")
    letter = user.name.first.upcase

    # Generate consistent color based on the first letter
    color_class = avatar_color_for_letter(letter)

    content_tag :div, class: "avatar" do
      content_tag :div, class: "#{size_class} rounded-full #{color_class} text-white flex items-center justify-center relative" do
        content_tag :span, letter, class: "#{text_size_class} font-bold absolute top-1/2 left-1/2 transform -translate-x-1/2 -translate-y-1/2"
      end
    end
  end

  private

  def avatar_color_for_letter(letter)
    # Array of nice background colors that work well with white text
    colors = [
      "bg-red-500",      # A-B
      "bg-orange-500",   # C-D
      "bg-amber-500",    # E-F
      "bg-yellow-500",   # G-H
      "bg-lime-500",     # I-J
      "bg-green-500",    # K-L
      "bg-emerald-500",  # M-N
      "bg-teal-500",     # O-P
      "bg-cyan-500",     # Q-R
      "bg-sky-500",      # S-T
      "bg-blue-500",     # U-V
      "bg-indigo-500",   # W-X
      "bg-purple-500"   # Y-Z
    ]

    # Convert letter to index (A=0, B=1, etc.)
    letter_index = letter.ord - "A".ord

    # Use modulo to handle edge cases and ensure we always get a valid color
    color_index = letter_index % colors.length

    colors[color_index]
  end
end
